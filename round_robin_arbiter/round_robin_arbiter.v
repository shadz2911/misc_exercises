module round_robin_arbiter (
    input clk,
    input rst_n,
    input [3:0] req,

    output reg [3:0] grant
);

reg [1:0] prio, next_prio;

always @(posedge clk) begin
    if (!rst_n) begin
        prio <= 2'b00;
    end else begin
        prio <= next_prio;
    end
end

always @(*) begin
    integer i;
    reg found;
    found = 1'b0;
    grant = 4'b0000;
    next_prio = prio;
    for (i=0; i<4; i=i+1) begin
        if (req[(prio + i) % 4] && !found) begin
            grant[(prio + i) % 4] = 1'b1;
            next_prio = (prio + i + 1) % 4;
            found = 1'b1;
        end
    end
end

endmodule