module skid_buffer #(
    parameter WIDTH = 8
) (
    input clk,
    input rst_n,

    input in_valid,
    input [WIDTH-1:0] in_data,
    output reg in_ready,

    output reg out_valid,
    output reg [WIDTH-1:0] out_data,
    input out_ready
);

localparam HOLD0=0, HOLD1=1, HOLD2=2;
reg [1:0] state, next_state;

reg skid_valid;
wire in = in_valid && in_ready;
wire out = out_valid && out_ready;
reg [WIDTH-1:0] skid_data;

always @(*) begin
    out_valid = (state != HOLD0);
    in_ready = (state != HOLD2);
    case (state)
        HOLD0: begin
            if (in) begin
                next_state = HOLD1;
            end else begin
                next_state = HOLD0;
            end
        end
        HOLD1: begin
            if (!in && !out) begin
                next_state = HOLD1;
            end else if (!in && out) begin
                next_state = HOLD0;
            end else if (in && !out) begin
                next_state = HOLD2;
            end else begin
                next_state = HOLD1;
            end
        end
        HOLD2: begin
            if (out) begin
                next_state = HOLD1;
            end else begin
                next_state = HOLD2;
            end
        end
        default: next_state = HOLD0;
    endcase
end

always @(posedge clk) begin
    if (!rst_n) begin
        state <= HOLD0;
        out_data <= 0;
        skid_data <= 0;
    end else begin
        state <= next_state;

        if ((state == HOLD2) && out) begin
            out_data <= skid_data;
        end else if (((state == HOLD0) && in) || ((state == HOLD1) && out)) begin
            out_data <= in_data;
        end

        if ((state == HOLD1) && in && !out) begin
            skid_data <= in_data;
        end
    end
end

endmodule