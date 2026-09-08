module div_3 (
    input clk,
    input areset,

    output div_3_clk
);

reg [1:0] pos_counter, neg_counter;

always @(posedge clk, posedge areset) begin
    if (areset) begin
        pos_counter <= 2'b00;
    end else begin
        if (pos_counter == 2'b10) begin
            pos_counter <= 2'b00;
        end else begin
            pos_counter <= pos_counter + 1;
        end
    end
end

always @(negedge clk, posedge areset) begin
    if (areset) begin
        neg_counter <= 2'b00;
    end else begin
        if (neg_counter == 2'b10) begin
            neg_counter <= 2'b00;
        end else begin
            neg_counter <= neg_counter + 1;
        end
    end
end

assign div_3_clk = (neg_counter == 2'b10) || (pos_counter == 2'b10);

endmodule