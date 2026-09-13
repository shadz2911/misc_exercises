`timescale 1ns/1ps

module top_round_robin_arbiter (
    input  wire       sysclk,   // W5, 100 MHz
    input  wire       btnC,     // reset, active-high pushbutton
    input  wire [3:0] sw,       // req
    output wire [3:0] led       // grant
);

    wire clk   = sysclk;
    wire rst_n = ~btnC;

    reg [3:0] req_meta, req_sync;
    always @(posedge clk) begin
        req_meta <= sw;
        req_sync <= req_meta;
    end

    wire [3:0] grant;

    round_robin_arbiter u_dut (
        .clk  (clk),
        .rst_n(rst_n),
        .req  (req_sync),
        .grant(grant)
    );

    assign led = grant;

endmodule
