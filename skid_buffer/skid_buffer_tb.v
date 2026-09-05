`timescale 1ns/1ps
//======================================================================
// skid_buffer_tb.v  --  self-checking testbench for skid_buffer
//
//   iverilog -o sim skid_buffer.v skid_buffer_tb.v && vvp sim
//   gtkwave skid_buffer_tb.vcd     # optional waveforms
//
// What it checks
//   * every accepted input beat leaves the buffer exactly once, in order
//   * nothing is dropped or duplicated under arbitrary back-pressure
//   * out_valid / out_data hold steady while a beat is stalled
//     (valid asserted, ready low)  -- the handshake stability rule
//   * in_ready deasserts when the buffer is full (2 beats held)
//   * full throughput: 64 beats in ~64 cycles when neither side bubbles
//   * no X on the handshake / payload during normal operation
//======================================================================
module skid_buffer_tb;

  localparam WIDTH = 8;

  // ---- DUT I/O ----
  reg              clk = 1'b0;
  reg              rst_n;
  reg              in_valid;
  reg  [WIDTH-1:0] in_data;
  wire             in_ready;
  wire             out_valid;
  wire [WIDTH-1:0] out_data;
  reg              out_ready;

  skid_buffer #(.WIDTH(WIDTH)) dut (
    .clk(clk), .rst_n(rst_n),
    .in_valid(in_valid), .in_data(in_data), .in_ready(in_ready),
    .out_valid(out_valid), .out_data(out_data), .out_ready(out_ready)
  );

  always #5 clk = ~clk;                  // 100 MHz

  // ---- scoreboard: expected-payload FIFO (buffer holds <=2, 256 is plenty) ----
  reg  [WIDTH-1:0] sb [0:255];
  reg  [7:0]       wrp, rdp;
  integer          n_sent, n_recv, n_err;

  // ---- stimulus knobs ----
  integer          in_bubble_pct, out_bubble_pct, target;
  reg  [WIDTH-1:0] sym;

  integer          c, guard;

  // 0..99
  function [6:0] pct;
    input integer unused;
    reg [31:0] r;
    begin
      r   = $random;
      pct = r % 100;
    end
  endfunction

  //------------------------------------------------------------------
  // producer: drives the input stream, obeys the stall obligation
  // (once in_valid is asserted, in_data/in_valid are held until accepted)
  //------------------------------------------------------------------
  task producer_step;
    begin
      if (in_valid && in_ready) begin         // beat accepted on the last posedge
        sym      = sym + 8'd1;
        in_valid = 1'b0;
      end
      if (!in_valid) begin                     // free to launch a fresh beat
        if (n_sent < target && pct(0) >= in_bubble_pct) begin
          in_valid = 1'b1;
          in_data  = sym;
        end
      end
      // otherwise: hold in_valid/in_data stable -> obligation honored
    end
  endtask

  //------------------------------------------------------------------
  // consumer: randomly (de)asserts out_ready
  //------------------------------------------------------------------
  task consumer_step;
    begin
      out_ready = (pct(0) >= out_bubble_pct);
    end
  endtask

  //------------------------------------------------------------------
  // monitor / checker  (samples pre-edge values at every posedge)
  //------------------------------------------------------------------
  reg             p_valid, p_ready;
  reg [WIDTH-1:0] p_data;

  always @(posedge clk) begin
    if (rst_n) begin
      // input transfer -> remember what we expect to see come out
      if (in_valid && in_ready) begin
        sb[wrp] = in_data;
        wrp     = wrp + 8'd1;
        n_sent  = n_sent + 1;
      end

      // output transfer -> check payload + ordering
      if (out_valid && out_ready) begin
        if (n_recv >= n_sent) begin
          $display("[%0t] ERROR: output beat but scoreboard empty (spurious/duplicate)",
                   $time);
          n_err = n_err + 1;
        end else if (out_data !== sb[rdp]) begin
          $display("[%0t] ERROR: payload mismatch beat %0d: got %02x exp %02x",
                   $time, n_recv, out_data, sb[rdp]);
          n_err = n_err + 1;
        end
        rdp    = rdp + 8'd1;
        n_recv = n_recv + 1;
      end

      // handshake stability: a beat offered but not taken must not change
      if (p_valid && !p_ready) begin
        if (out_valid !== 1'b1) begin
          $display("[%0t] ERROR: out_valid dropped while beat un-accepted", $time);
          n_err = n_err + 1;
        end
        if (out_data !== p_data) begin
          $display("[%0t] ERROR: out_data changed while beat un-accepted", $time);
          n_err = n_err + 1;
        end
      end

      // X screen
      if (out_valid === 1'bx || in_ready === 1'bx) begin
        $display("[%0t] ERROR: X on handshake (out_valid=%b in_ready=%b)",
                 $time, out_valid, in_ready);
        n_err = n_err + 1;
      end
      if (out_valid === 1'b1 && (^out_data) === 1'bx) begin
        $display("[%0t] ERROR: X on out_data while out_valid", $time);
        n_err = n_err + 1;
      end
    end
    p_valid <= out_valid;
    p_ready <= out_ready;
    p_data  <= out_data;
  end

  //------------------------------------------------------------------
  // helpers
  //------------------------------------------------------------------
  task do_reset;
    begin
      rst_n = 1'b0; in_valid = 1'b0; in_data = 0; out_ready = 1'b0;
      sym = 0; wrp = 0; rdp = 0; n_sent = 0; n_recv = 0;
      p_valid = 0; p_ready = 0; p_data = 0;
      repeat (3) @(negedge clk);
      rst_n = 1'b1;
      @(negedge clk);
    end
  endtask

  task step;                            // one cycle of stimulus
    begin
      @(negedge clk);
      producer_step;
      consumer_step;
    end
  endtask

  task run_random(input integer ib, input integer ob, input integer nb);
    integer g;
    begin
      do_reset;
      in_bubble_pct = ib; out_bubble_pct = ob; target = nb;
      g = 0;
      while (n_recv < target && g < nb*200 + 2000) begin
        step; g = g + 1;
      end
      // guaranteed flush: stop feeding, open the output
      in_bubble_pct = 100; out_bubble_pct = 0;
      repeat (32) step;
      if (n_recv === target)
        $display("Random(in=%0d%% out=%0d%%): ok   %0d beats in %0d cycles",
                 ib, ob, target, g);
      else begin
        $display("Random(in=%0d%% out=%0d%%): FAIL recv=%0d target=%0d",
                 ib, ob, n_recv, target);
        n_err = n_err + 1;
      end
    end
  endtask

  //------------------------------------------------------------------
  // test program
  //------------------------------------------------------------------
  initial begin
    $dumpfile("skid_buffer_tb.vcd");
    $dumpvars(0, skid_buffer_tb);
    n_err = 0;

    // ---- Test 1: full throughput, no bubbles either side ----
    do_reset;
    in_bubble_pct = 0; out_bubble_pct = 0; target = 64;
    c = 0;
    while (n_recv < target && c < 300) begin
      step; c = c + 1;
    end
    if (n_recv === target && c <= target + 8)
      $display("Test1 THROUGHPUT   : ok   %0d beats in %0d cycles", target, c);
    else begin
      $display("Test1 THROUGHPUT   : FAIL recv=%0d target=%0d cycles=%0d (expected ~%0d)",
               n_recv, target, c, target);
      n_err = n_err + 1;
    end

    // ---- Test 2: fill until full, verify in_ready drops, then drain ----
    do_reset;
    in_bubble_pct = 0; out_bubble_pct = 100; target = 16;
    repeat (12) step;
    if (in_ready !== 1'b0) begin
      $display("Test2 FULL         : FAIL in_ready=%b (buffer should be full)", in_ready);
      n_err = n_err + 1;
    end
    if (out_valid !== 1'b1) begin
      $display("Test2 FULL         : FAIL out_valid=%b (should be holding a beat)", out_valid);
      n_err = n_err + 1;
    end
    if (in_ready === 1'b0 && out_valid === 1'b1)
      $display("Test2 FULL         : ok   in_ready low, out_valid high, n_sent=%0d", n_sent);
    out_bubble_pct = 0;                 // release downstream
    guard = 0;
    while (n_recv < target && guard < 5000) begin
      step; guard = guard + 1;
    end
    if (n_recv === target)
      $display("Test2 STALL+DRAIN  : ok   %0d beats recovered", target);
    else begin
      $display("Test2 STALL+DRAIN  : FAIL recv=%0d target=%0d", n_recv, target);
      n_err = n_err + 1;
    end

    // ---- Test 3-6: randomized back-pressure ----
    run_random(30, 30, 400);
    run_random(80, 15, 400);   // starved input
    run_random(15, 80, 400);   // slow output
    run_random(50, 50, 800);

    $display("--------------------------------------------------");
    if (n_err == 0) $display("*** ALL TESTS PASSED ***");
    else            $display("*** %0d ERROR(S) ***", n_err);
    $display("--------------------------------------------------");
    $finish;
  end

  // global watchdog
  initial begin
    #5_000_000;
    $display("*** GLOBAL TIMEOUT -- something is hung ***");
    n_err = n_err + 1;
    $finish;
  end

endmodule
