module glitch_free_clock_mux (
    input clk_a,
    input clk_b,
    input rst_n,     
    input sel,         

    output clk_out
);

// 0 means clk_a, 1 means clk_b

reg sel_a, sel_a_synced, sel_b, sel_b_synced;

always @(negedge clk_a, negedge rst_n) begin
    if (!rst_n) begin
        sel_a <= 1'b0;
        sel_a_synced <= 1'b0;
    end else begin
        sel_a <= !sel_b_synced && !sel;
        sel_a_synced <= sel_a;
    end
end

always @(negedge clk_b, negedge rst_n) begin
    if (!rst_n) begin
        sel_b <= 1'b0;
        sel_b_synced <= 1'b0;
    end else begin
        sel_b <= !sel_a_synced && sel;
        sel_b_synced <= sel_b;
    end
end

assign clk_out = (clk_a && sel_a_synced) | (clk_b && sel_b_synced);

endmodule