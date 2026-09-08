`timescale 1ns/1ps

module div_3_tb;

    reg  clk;
    reg  areset;
    wire div_3_clk;

    // DUT
    div_3 dut (
        .clk       (clk),
        .areset    (areset),
        .div_3_clk (div_3_clk)
    );

    // 100 MHz reference clock (10 ns period)
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Stimulus
    initial begin
        $dumpfile("div_3_tb.vcd");
        $dumpvars(0, div_3_tb);

        areset = 1'b1;
        repeat (3) @(posedge clk);
        @(negedge clk) areset = 1'b0;

        // run long enough to see several output periods
        repeat (30) @(posedge clk);

        // exercise async reset again mid-stream
        areset = 1'b1;
        #7 areset = 1'b0;

        repeat (20) @(posedge clk);

        $display("Simulation finished at %0t", $time);
        $finish;
    end

    // Simple checker: measure output period once out of reset
    real t_rise, prev_rise, meas_period;
    initial begin
        prev_rise = 0.0;
        forever begin
            @(posedge div_3_clk);
            t_rise = $realtime;
            if (prev_rise != 0.0 && !areset) begin
                meas_period = t_rise - prev_rise;
                $display("[%0t] div_3_clk period = %0.1f ns (expect 30.0)", $time, meas_period);
            end
            prev_rise = t_rise;
        end
    end

endmodule
