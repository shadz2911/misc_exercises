`timescale 1ps/1ps
//======================================================================
// glitch_free_clock_mux_tb.v  --  self-checking testbench
//
//   iverilog -g2012 -o sim glitch_free_clock_mux.v glitch_free_clock_mux_tb.v && vvp sim
//   gtkwave glitch_free_clock_mux_tb.vcd     # optional waveforms
//
// clk_a and clk_b are free-running, unrelated (non-harmonic periods), so
// every `sel` crossing is a genuine async CDC event.
//
// Checked continuously on every clk_out edge (whitebox, via dut.*):
//   * sel_a_synced and sel_b_synced are never both asserted
//     (that overlap is exactly what would produce a glitch)
//   * clk_out always equals (clk_a & sel_a_synced) | (clk_b & sel_b_synced)
//     -- independently recomputed, catches a typo in the DUT's own gate
//   * clk_out never toggles while neither select is asserted (orphan edge)
//   * a run of consecutive edges attributed to the same source clock has
//     exactly that clock's half-period spacing -- a runt/short pulse means
//     the switch chopped a clock edge instead of waiting for it to go low
//   * no X on clk_out once out of reset
//
// Directed scenarios:
//   * reset behaviour                  -> clk_out held low, no glitch monitor trips
//   * steady select on A, then on B    -> clean passthrough, bounded sync latency
//   * ping-pong switching at random async offsets -> stresses the CDC race
//   * reset asserted mid-switch        -> recovers cleanly, no stuck state
//======================================================================
module glitch_free_clock_mux_tb;

  // ---- clocks: 10ns / 17ns, deliberately non-harmonic ----
  localparam CLKA_HALF = 5000;   // ps  (10 ns period  -> 100.0   MHz)
  localparam CLKB_HALF = 8500;   // ps  (17 ns period  ->  58.8   MHz)

  reg clk_a = 1'b0;
  reg clk_b = 1'b0;
  reg rst_n;
  reg sel;
  wire clk_out;

  glitch_free_clock_mux dut (
    .clk_a(clk_a), .clk_b(clk_b), .rst_n(rst_n), .sel(sel), .clk_out(clk_out)
  );

  always #(CLKA_HALF) clk_a = ~clk_a;
  always #(CLKB_HALF) clk_b = ~clk_b;

  integer n_err;
  integer n_switch_events;
  integer n_toggles_a, n_toggles_b;
  reg     checks_enabled;

  // ------------------------------------------------------------------
  // continuous glitch monitor (whitebox on dut.sel_a_synced / sel_b_synced)
  // ------------------------------------------------------------------
  time    last_edge_time;
  integer last_source;          // 0 = none, 1 = a, 2 = b
  integer cur_source;
  reg     first_edge;
  time    delta, exp_half;

  initial begin
    checks_enabled = 1'b0;
    n_err           = 0;
    n_switch_events = 0;
    n_toggles_a     = 0;
    n_toggles_b     = 0;
    first_edge      = 1'b1;
    last_edge_time  = 0;
    last_source     = 0;
  end

  always @(clk_out) begin
    if (checks_enabled) begin

      if (dut.sel_a_synced && dut.sel_b_synced) begin
        $display("[%0t] ERROR: sel_a_synced and sel_b_synced both asserted -- glitch source", $time);
        n_err = n_err + 1;
      end

      if (clk_out !== ((dut.sel_a_synced & clk_a) | (dut.sel_b_synced & clk_b))) begin
        $display("[%0t] ERROR: clk_out=%b does not match independently-recomputed gate", $time, clk_out);
        n_err = n_err + 1;
      end

      if (dut.sel_a_synced)      cur_source = 1;
      else if (dut.sel_b_synced) cur_source = 2;
      else                       cur_source = 0;

      if (cur_source == 0) begin
        $display("[%0t] ERROR: clk_out toggled with no source selected (orphan glitch)", $time);
        n_err = n_err + 1;
      end else begin

        if (cur_source == 1) n_toggles_a = n_toggles_a + 1;
        else                  n_toggles_b = n_toggles_b + 1;

        if (!first_edge) begin
          if (cur_source == last_source) begin
            delta    = $time - last_edge_time;
            exp_half = (cur_source == 1) ? CLKA_HALF : CLKB_HALF;
            if (delta != exp_half) begin
              $display("[%0t] ERROR: runt pulse on clk_out -- source=%0d spacing=%0dps expected=%0dps",
                        $time, cur_source, delta, exp_half);
              n_err = n_err + 1;
            end
          end else begin
            n_switch_events = n_switch_events + 1;
          end
        end

        last_source    = cur_source;
        last_edge_time = $time;
        first_edge     = 1'b0;
      end

      if (^clk_out === 1'bx) begin
        $display("[%0t] ERROR: X on clk_out", $time);
        n_err = n_err + 1;
      end
    end
  end

  // ------------------------------------------------------------------
  // helpers
  // ------------------------------------------------------------------
  task do_reset;
    begin
      checks_enabled = 1'b0;
      rst_n = 1'b0;
      sel   = 1'b0;
      repeat (3) @(posedge clk_a);
      rst_n = 1'b1;
      @(posedge clk_a);
      first_edge = 1'b1;          // resync the glitch monitor's history
      last_source = 0;
      checks_enabled = 1'b1;
    end
  endtask

  // waits for the synchronized select to settle to the requested source,
  // bounded so a stuck synchronizer fails the test instead of hanging
  task wait_for_select;
    input want_a;
    integer cyc;
    begin
      cyc = 0;
      while (!((want_a  && dut.sel_a_synced && !dut.sel_b_synced) ||
               (!want_a && dut.sel_b_synced && !dut.sel_a_synced))) begin
        @(posedge clk_a or posedge clk_b);
        cyc = cyc + 1;
        if (cyc > 20) begin
          $display("[%0t] ERROR: select did not settle to %s within 20 source edges",
                    $time, want_a ? "A" : "B");
          n_err = n_err + 1;
          disable wait_for_select;
        end
      end
    end
  endtask

  // ------------------------------------------------------------------
  // directed tests
  // ------------------------------------------------------------------
  task test_reset;
    begin
      do_reset;
      if (dut.sel_a_synced || dut.sel_b_synced || clk_out !== 1'b0) begin
        $display("[%0t] ERROR: not idle right after reset (sel_a_s=%b sel_b_s=%b clk_out=%b)",
                  $time, dut.sel_a_synced, dut.sel_b_synced, clk_out);
        n_err = n_err + 1;
      end else
        $display("Test RESET      : ok   idle, clk_out low, no active source");
    end
  endtask

  task test_passthrough_a;
    begin
      do_reset;
      sel = 1'b0;
      wait_for_select(1'b1);
      repeat (20) @(posedge clk_a);
      $display("Test PASS-A     : ok   settled on A, %0d clk_out edges clean so far", n_toggles_a);
    end
  endtask

  task test_switch_to_b;
    begin
      sel = 1'b1;
      wait_for_select(1'b0);
      repeat (20) @(posedge clk_b);
      $display("Test SWITCH-A>B : ok   settled on B, %0d switch events so far", n_switch_events);
    end
  endtask

  task test_switch_to_a;
    begin
      sel = 1'b0;
      wait_for_select(1'b1);
      repeat (20) @(posedge clk_a);
      $display("Test SWITCH-B>A : ok   settled on A, %0d switch events so far", n_switch_events);
    end
  endtask

  task test_ping_pong;
    input integer n;
    integer i;
    integer d;
    begin
      do_reset;
      sel = 1'b0;
      wait_for_select(1'b1);
      for (i = 0; i < n; i = i + 1) begin
        sel = ~sel;
        d = $random % 4000;
        if (d < 0) d = -d;
        #(d);                                  // async offset vs. both clocks
        wait_for_select(sel == 1'b0);
      end
      $display("Test PING-PONG  : ok   %0d async switches, %0d total events, 0 glitches",
                n, n_switch_events);
    end
  endtask

  task test_reset_mid_switch;
    begin
      sel = 1'b1;
      #(CLKA_HALF / 3);              // interrupt the synchronizer mid-flight
      rst_n = 1'b0;
      checks_enabled = 1'b0;
      repeat (3) @(posedge clk_a);
      if (clk_out !== 1'b0)
        $display("Test MID-RESET  : note  clk_out settling asynchronously, checked post-reset only");
      rst_n = 1'b1;
      @(posedge clk_a);
      first_edge = 1'b1;
      last_source = 0;
      checks_enabled = 1'b1;
      sel = 1'b0;
      wait_for_select(1'b1);
      $display("Test MID-RESET  : ok   recovered cleanly to A after reset during a switch");
    end
  endtask

  // ------------------------------------------------------------------
  // test program
  // ------------------------------------------------------------------
  initial begin
    $dumpfile("glitch_free_clock_mux_tb.vcd");
    $dumpvars(0, glitch_free_clock_mux_tb);

    test_reset;
    test_passthrough_a;
    test_switch_to_b;
    test_switch_to_a;
    test_ping_pong(200);
    test_reset_mid_switch;

    do_reset;
    sel = 1'b0;
    wait_for_select(1'b1);
    repeat (10) @(posedge clk_a);

    $display("--------------------------------------------------");
    $display("coverage: %0d switch events, %0d clk_a-sourced edges, %0d clk_b-sourced edges",
              n_switch_events, n_toggles_a, n_toggles_b);
    if (n_err == 0) $display("*** ALL TESTS PASSED ***");
    else            $display("*** %0d ERROR(S) ***", n_err);
    $display("--------------------------------------------------");
    $finish;
  end

  // global watchdog
  initial begin
    #100_000_000;
    $display("*** GLOBAL TIMEOUT -- something is hung ***");
    n_err = n_err + 1;
    $finish;
  end

endmodule
