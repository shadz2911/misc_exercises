`timescale 1ns/1ps
//======================================================================
// round_robin_arbiter_tb.v  --  self-checking testbench
//
//   iverilog -g2012 -o sim round_robin_arbiter.v round_robin_arbiter_tb.v && vvp sim
//   gtkwave round_robin_arbiter_tb.vcd     # optional waveforms
//
// grant is a purely combinational function of the registered priority
// pointer `prio` and `req`.  The correctness monitor runs at posedge:
// there `grant` still reflects the *current* pointer (the NBA update to
// `prio` has not committed yet), and the reference model advances with
// the exact same `req` the DUT sees, so the two stay in lock-step.
// Stimulus is driven at negedge, half a cycle away, so there is no race.
//
// Checked every cycle against the reference model:
//   * grant is one-hot or zero            (never two winners)
//   * grant is a subset of req            (never grant an idle channel)
//   * grant == 0  iff  req == 0
//   * grant == the reference round-robin pick
//     (first asserted req at/after the rotating pointer)
//   * a continuously-held request is served within 4 cycles (fairness)
//   * no X on grant
//
// Directed scenarios:
//   * all four lines high  -> grant left-rotates one hot bit per cycle
//   * two lines high       -> strict alternation, no starvation
//   * one steady line      -> served every cycle
//   * randomized req       -> reference-model equivalence under stress
//======================================================================
module round_robin_arbiter_tb;

  // ---- DUT I/O ----
  reg        clk = 1'b0;
  reg        rst_n;
  reg  [3:0] req;
  wire [3:0] grant;

  round_robin_arbiter dut (
    .clk(clk), .rst_n(rst_n), .req(req), .grant(grant)
  );

  always #5 clk = ~clk;                 // 100 MHz

  integer n_err;

  // ------------------------------------------------------------------
  // reference model
  // ------------------------------------------------------------------
  reg [1:0] mprio;                      // mirrors the DUT priority register

  function [3:0] ref_grant;
    input [1:0] p;
    input [3:0] r;
    integer i;
    reg     found;
    begin
      ref_grant = 4'b0000;
      found     = 1'b0;
      for (i = 0; i < 4; i = i + 1)
        if (r[(p + i) % 4] && !found) begin
          ref_grant[(p + i) % 4] = 1'b1;
          found = 1'b1;
        end
    end
  endfunction

  function [1:0] ref_next_prio;
    input [1:0] p;
    input [3:0] r;
    integer i;
    reg     found;
    begin
      ref_next_prio = p;
      found         = 1'b0;
      for (i = 0; i < 4; i = i + 1)
        if (r[(p + i) % 4] && !found) begin
          ref_next_prio = (p + i + 1) % 4;
          found = 1'b1;
        end
    end
  endfunction

  function is_onehot0;                  // 1 if v has <= 1 bit set
    input [3:0] v;
    begin
      is_onehot0 = ((v & (v - 1)) == 4'b0);
    end
  endfunction

  // ------------------------------------------------------------------
  // correctness monitor (posedge, pre-NBA)
  // ------------------------------------------------------------------
  reg [3:0] eg;
  reg [7:0] held [0:3];                 // consecutive held-without-grant cycles
  integer   m;

  always @(posedge clk) begin
    if (!rst_n) begin
      mprio <= 2'b00;
      for (m = 0; m < 4; m = m + 1) held[m] <= 8'd0;
    end else begin
      eg = ref_grant(mprio, req);

      if (grant !== eg) begin
        $display("[%0t] ERROR: grant=%b exp=%b  (req=%b prio=%0d)",
                 $time, grant, eg, req, mprio);
        n_err = n_err + 1;
      end
      if (!is_onehot0(grant)) begin
        $display("[%0t] ERROR: grant not one-hot/zero: %b", $time, grant);
        n_err = n_err + 1;
      end
      if ((grant & ~req) !== 4'b0) begin
        $display("[%0t] ERROR: granted an idle channel: grant=%b req=%b",
                 $time, grant, req);
        n_err = n_err + 1;
      end
      if ((req == 4'b0) && (grant !== 4'b0)) begin
        $display("[%0t] ERROR: grant=%b with no request", $time, grant);
        n_err = n_err + 1;
      end
      if ((req != 4'b0) && (grant == 4'b0)) begin
        $display("[%0t] ERROR: no grant while req=%b", $time, req);
        n_err = n_err + 1;
      end
      if (^grant === 1'bx) begin
        $display("[%0t] ERROR: X on grant: %b", $time, grant);
        n_err = n_err + 1;
      end

      // fairness bound: a held request must win within 4 cycles
      for (m = 0; m < 4; m = m + 1) begin
        if (grant[m] || !req[m])
          held[m] <= 8'd0;
        else begin
          held[m] <= held[m] + 8'd1;
          if (held[m] + 8'd1 > 8'd4) begin
            $display("[%0t] ERROR: channel %0d starved %0d cycles (req held)",
                     $time, m, held[m] + 8'd1);
            n_err = n_err + 1;
          end
        end
      end

      mprio <= ref_next_prio(mprio, req);
    end
  end

  // ------------------------------------------------------------------
  // helpers
  // ------------------------------------------------------------------
  task do_reset;
    begin
      rst_n = 1'b0;
      req   = 4'b0000;
      repeat (3) @(negedge clk);
      rst_n = 1'b1;
      @(negedge clk);
    end
  endtask

  // ------------------------------------------------------------------
  // directed coverage checks (correctness itself is on the monitor)
  // ------------------------------------------------------------------
  reg [3:0] seen, prev;
  integer   k, c1, c3, hits;

  task test_all_high;
    begin
      do_reset;
      req  = 4'b1111;
      seen = 4'b0000;
      prev = 4'b0000;
      for (k = 0; k < 12; k = k + 1) begin
        @(negedge clk);
        seen = seen | grant;
        if (k > 0 && grant !== {prev[2:0], prev[3]}) begin
          $display("[%0t] ERROR: all-high: grant=%b not a left-rotate of %b",
                   $time, grant, prev);
          n_err = n_err + 1;
        end
        prev = grant;
      end
      if (seen === 4'b1111)
        $display("Test ALL-HIGH   : ok   4 channels, strict one-bit rotation");
      else begin
        $display("Test ALL-HIGH   : FAIL coverage seen=%b", seen);
        n_err = n_err + 1;
      end
    end
  endtask

  task test_two_high;
    begin
      do_reset;
      req = 4'b1010;                    // channels 1 and 3
      c1 = 0; c3 = 0;
      for (k = 0; k < 20; k = k + 1) begin
        @(negedge clk);
        if (grant[1]) c1 = c1 + 1;
        if (grant[3]) c3 = c3 + 1;
      end
      if (c1 == 10 && c3 == 10)
        $display("Test TWO-HIGH   : ok   ch1=%0d ch3=%0d (alternating)", c1, c3);
      else begin
        $display("Test TWO-HIGH   : FAIL ch1=%0d ch3=%0d", c1, c3);
        n_err = n_err + 1;
      end
    end
  endtask

  task test_single;
    begin
      do_reset;
      req  = 4'b0100;                   // only channel 2
      hits = 0;
      for (k = 0; k < 16; k = k + 1) begin
        @(negedge clk);
        if (grant === 4'b0100) hits = hits + 1;
      end
      if (hits == 16)
        $display("Test SINGLE     : ok   channel 2 served every cycle");
      else begin
        $display("Test SINGLE     : FAIL hits=%0d/16", hits);
        n_err = n_err + 1;
      end
    end
  endtask

  task test_random;
    input integer n;
    reg [3:0] rr;
    begin
      do_reset;
      for (k = 0; k < n; k = k + 1) begin
        rr  = $random;
        req = rr;
        @(negedge clk);
      end
      $display("Test RANDOM     : ok   %0d cycles, model-equivalent, fairness held", n);
    end
  endtask

  // ------------------------------------------------------------------
  // test program
  // ------------------------------------------------------------------
  initial begin
    $dumpfile("round_robin_arbiter_tb.vcd");
    $dumpvars(0, round_robin_arbiter_tb);
    n_err = 0;

    // idle: no request -> no grant
    do_reset;
    req = 4'b0000;
    repeat (3) @(negedge clk);

    test_all_high;
    test_two_high;
    test_single;
    test_random(4000);

    do_reset;
    req = 4'b0000;
    repeat (2) @(negedge clk);

    $display("--------------------------------------------------");
    if (n_err == 0) $display("*** ALL TESTS PASSED ***");
    else            $display("*** %0d ERROR(S) ***", n_err);
    $display("--------------------------------------------------");
    $finish;
  end

  // global watchdog
  initial begin
    #1_000_000;
    $display("*** GLOBAL TIMEOUT -- something is hung ***");
    n_err = n_err + 1;
    $finish;
  end

endmodule
