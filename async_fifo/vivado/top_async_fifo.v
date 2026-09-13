`timescale 1ns/1ps

module top_async_fifo (
    input  wire        sysclk,   // W5, 100 MHz
    input  wire        btnC,     // reset, active-high pushbutton
    input  wire        btnU,     // wr_en source
    input  wire        btnD,     // rd_en source
    input  wire [7:0]  sw,       // wr_data
    output wire [15:0] led
);

    wire sysclk_ibuf, sysclk_bufg;
    IBUF u_ibuf (.I(sysclk), .O(sysclk_ibuf));
    BUFG u_bufg (.I(sysclk_ibuf), .O(sysclk_bufg));

    wire clkfb, clkfb_bufg;
    wire wr_clk_raw, rd_clk_raw, wr_clk, rd_clk;
    wire mmcm_locked;

    MMCME2_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKFBOUT_MULT_F    (8.000),
        .CLKFBOUT_PHASE     (0.0),
        .CLKIN1_PERIOD      (10.000),
        .CLKOUT0_DIVIDE_F   (12.000),
        .CLKOUT0_DUTY_CYCLE (0.5),
        .CLKOUT0_PHASE      (0.0),
        .CLKOUT1_DIVIDE     (7),
        .CLKOUT1_DUTY_CYCLE (0.5),
        .CLKOUT1_PHASE      (0.0),
        .CLKOUT4_CASCADE    ("FALSE"),
        .DIVCLK_DIVIDE      (1),
        .REF_JITTER1        (0.010),
        .STARTUP_WAIT       ("FALSE")
    ) u_mmcm (
        .CLKIN1   (sysclk_bufg),
        .CLKFBIN  (clkfb_bufg),
        .CLKFBOUT (clkfb),
        .CLKOUT0  (wr_clk_raw),
        .CLKOUT1  (rd_clk_raw),
        .LOCKED   (mmcm_locked),
        .PWRDWN   (1'b0),
        .RST      (1'b0)
    );

    BUFG u_bufg_fb (.I(clkfb),      .O(clkfb_bufg));
    BUFG u_bufg_wr (.I(wr_clk_raw), .O(wr_clk));
    BUFG u_bufg_rd (.I(rd_clk_raw), .O(rd_clk));

    wire rst_n = ~btnC & mmcm_locked;

    reg [1:0] wr_en_sync;
    always @(posedge wr_clk or negedge rst_n)
        if (!rst_n) wr_en_sync <= 2'b00;
        else        wr_en_sync <= {wr_en_sync[0], btnU};

    reg [1:0] rd_en_sync;
    always @(posedge rd_clk or negedge rst_n)
        if (!rst_n) rd_en_sync <= 2'b00;
        else        rd_en_sync <= {rd_en_sync[0], btnD};

    wire [7:0] rd_data;
    wire       full, empty;

    async_fifo u_dut (
        .wr_clk  (wr_clk),
        .rd_clk  (rd_clk),
        .rst_n   (rst_n),
        .wr_en   (wr_en_sync[1]),
        .wr_data (sw),
        .rd_en   (rd_en_sync[1]),
        .rd_data (rd_data),
        .full    (full),
        .empty   (empty)
    );

    assign led[7:0]   = rd_data;
    assign led[8]     = mmcm_locked;
    assign led[13:9]  = 5'b0;
    assign led[14]    = full;
    assign led[15]    = empty;

endmodule
