`timescale 1ns/1ps
//
// Testbench for async_fifo.sv
//
//  - two asynchronous clocks (write faster than read, then swapped in a 2nd pass)
//  - reference model (SystemVerilog queue) acts as a golden FIFO
//  - self-checking: data integrity, overflow (write accepted while "really" full),
//    underflow (read accepted while "really" empty)
//
// Run with Icarus:
//   iverilog -g2012 -o sim.out async_fifo.sv async_fifo_tb.sv && vvp sim.out
//
module async_fifo_tb;

  localparam int DEPTH = 16;   // must match the DUT memory depth

  // ---------------------------------------------------------------- DUT I/O
  logic        wr_clk = 0;
  logic        rd_clk = 0;
  logic        rst_n;
  logic        wr_en;
  logic [7:0]  wr_data;
  logic        rd_en;
  logic [7:0]  rd_data;
  logic        full;
  logic        empty;

  async_fifo dut (
    .wr_clk (wr_clk),
    .rd_clk (rd_clk),
    .rst_n  (rst_n),
    .wr_en  (wr_en),
    .wr_data(wr_data),
    .rd_en  (rd_en),
    .rd_data(rd_data),
    .full   (full),
    .empty  (empty)
  );

  // ---------------------------------------------------------------- clocks
  real wr_half = 5.0;    // 10 ns  write clock
  real rd_half = 7.0;    // 14 ns  read  clock
  always #(wr_half) wr_clk = ~wr_clk;
  always #(rd_half) rd_clk = ~rd_clk;

  // ---------------------------------------------------------------- scoreboard
  logic [7:0] model_q [$];
  int errors      = 0;
  int writes_done = 0;
  int reads_done  = 0;

  task automatic flag(input string msg);
    $display("  *** ERROR @%0t: %s", $time, msg);
    errors++;
  endtask

  // Write side: a write is "accepted" on the wr_clk edge when wr_en & !full.
  always @(posedge wr_clk) begin
    if (rst_n === 1'b1 && wr_en && !full) begin
      if (model_q.size() >= DEPTH)
        flag($sformatf("OVERFLOW - write accepted, model already holds %0d entries", model_q.size()));
      model_q.push_back(wr_data);
      writes_done++;
    end
  end

  // Read side: async_fifo drives rd_data combinationally from the current
  // rd_ptr and advances rd_ptr on this same posedge, so the consumed beat must
  // be sampled with the pre-edge values, i.e. right here on posedge rd_clk.
  always @(posedge rd_clk) begin
    logic [7:0] exp;
    if (rst_n === 1'b1 && rd_en && !empty) begin
      if (model_q.size() == 0) begin
        flag("UNDERFLOW - DUT reports !empty but golden model is empty");
      end else begin
        exp = model_q.pop_front();
        if (rd_data !== exp)
          flag($sformatf("DATA MISMATCH - got 0x%02h expected 0x%02h", rd_data, exp));
        reads_done++;
      end
    end
  end

  // ---------------------------------------------------------------- helpers
  task automatic do_reset;
    wr_en   = 0;
    rd_en   = 0;
    wr_data = 0;
    rst_n   = 0;
    repeat (4) @(posedge wr_clk);
    repeat (4) @(posedge rd_clk);
    @(negedge wr_clk) rst_n = 1;
    model_q.delete();
    repeat (2) @(posedge wr_clk);
  endtask

  // continuously drive writes for n wr_clk cycles with a given assert probability
  task automatic drive_writes(input int cycles, input int pct);
    for (int i = 0; i < cycles; i++) begin
      @(negedge wr_clk);
      if (($urandom_range(0,99)) < pct) begin
        wr_en   <= 1'b1;
        wr_data <= $urandom;
      end else begin
        wr_en <= 1'b0;
      end
    end
    @(negedge wr_clk) wr_en <= 1'b0;
  endtask

  task automatic drive_reads(input int cycles, input int pct);
    for (int i = 0; i < cycles; i++) begin
      @(negedge rd_clk);
      rd_en <= (($urandom_range(0,99)) < pct);
    end
    @(negedge rd_clk) rd_en <= 1'b0;
  endtask

  // ---------------------------------------------------------------- tests
  initial begin
    $dumpfile("async_fifo_tb.vcd");
    $dumpvars(0, async_fifo_tb);

    // -------- Test 0: reset behaviour
    $display("[Test 0] reset");
    do_reset();
    if (empty !== 1'b1) flag("after reset: empty should be 1");
    if (full  !== 1'b0) flag("after reset: full should be 0");

    // -------- Test 1: fill the FIFO with no reads, then drain it
    $display("[Test 1] fill then drain, check data order & no overflow");
    fork
      drive_writes(DEPTH + 8, 100);   // push harder than it can hold
    join
    repeat (10) @(posedge wr_clk);    // let full propagate
    if (!full)
      flag($sformatf("FIFO not full after %0d write attempts (accepted %0d)", DEPTH+8, writes_done));

    drive_reads(DEPTH + 20, 100);
    repeat (10) @(posedge rd_clk);
    if (!empty) flag("FIFO not empty after draining");
    if (model_q.size() != 0)
      flag($sformatf("golden model still holds %0d entries after drain", model_q.size()));

    // -------- Test 2: concurrent random read/write, write-heavy
    $display("[Test 2] random concurrent traffic (write-heavy)");
    do_reset();
    fork
      drive_writes(400, 75);
      drive_reads (400, 40);
    join
    // drain remainder
    drive_reads(600, 100);
    repeat (10) @(posedge rd_clk);
    if (model_q.size() != 0)
      flag($sformatf("Test 2: %0d entries left unread", model_q.size()));

    // -------- Test 3: random concurrent traffic, read-heavy
    $display("[Test 3] random concurrent traffic (read-heavy)");
    do_reset();
    fork
      drive_writes(400, 35);
      drive_reads (400, 90);
    join
    drive_reads(400, 100);
    repeat (10) @(posedge rd_clk);
    if (model_q.size() != 0)
      flag($sformatf("Test 3: %0d entries left unread", model_q.size()));

    // -------- Test 4: swap clock rates (read faster than write)
    $display("[Test 4] read clock faster than write clock");
    wr_half = 8.0;   // 16 ns
    rd_half = 3.0;   //  6 ns
    do_reset();
    fork
      drive_writes(300, 60);
      drive_reads (800, 70);
    join
    drive_reads(400, 100);
    repeat (10) @(posedge rd_clk);
    if (model_q.size() != 0)
      flag($sformatf("Test 4: %0d entries left unread", model_q.size()));

    // ---------------------------------------------------------------- summary
    $display("--------------------------------------------------");
    $display("writes accepted : %0d", writes_done);
    $display("reads  checked  : %0d", reads_done);
    if (errors == 0) $display("RESULT: PASS");
    else             $display("RESULT: FAIL (%0d errors)", errors);
    $display("--------------------------------------------------");
    $finish;
  end

  // global watchdog
  initial begin
    #500000;
    $display("*** ERROR: watchdog timeout");
    $finish;
  end

endmodule
