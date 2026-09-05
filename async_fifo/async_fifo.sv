module async_fifo (
    input wr_clk,
    input rd_clk,
    input rst_n,
    input wr_en,
    input [7:0] wr_data,
    input rd_en,

    output [7:0] rd_data,
    output full,
    output empty
);

reg [7:0] data [0:15];
wire [4:0] rd_ptr_gray, wr_ptr_gray, rd_ptr_transferred, wr_ptr_transferred;
reg [4:0] rd_ptr, wr_ptr, rd_ptr_gray_asynced, rd_ptr_gray_synced, wr_ptr_gray_asynced, wr_ptr_gray_synced;

norm_to_gray read (.in(rd_ptr), .out(rd_ptr_gray));
norm_to_gray write (.in(wr_ptr), .out(wr_ptr_gray));
gray_to_norm read_transfer (.in(rd_ptr_gray_synced), .out(rd_ptr_transferred));
gray_to_norm write_transfer (.in(wr_ptr_gray_synced), .out(wr_ptr_transferred));

always @(posedge wr_clk, negedge rst_n) begin
    if (!rst_n) begin
        wr_ptr <= 0;
        rd_ptr_gray_asynced <= 0;
        rd_ptr_gray_synced <= 0;
    end else begin
        rd_ptr_gray_asynced <= rd_ptr_gray;
        rd_ptr_gray_synced <= rd_ptr_gray_asynced;
        if (wr_en && !full) begin
            wr_ptr <= wr_ptr + 1;
            data[wr_ptr[3:0]] <= wr_data;
        end
    end
end

always @(posedge rd_clk, negedge rst_n) begin
    if (!rst_n) begin
        rd_ptr <= 0;
        wr_ptr_gray_asynced <= 0;
        wr_ptr_gray_synced <= 0;
    end else begin
        wr_ptr_gray_asynced <= wr_ptr_gray;
        wr_ptr_gray_synced <= wr_ptr_gray_asynced;
        if (rd_en && !empty) begin
            rd_ptr <= rd_ptr + 1;
        end
    end
end

assign empty = (wr_ptr_transferred[4] == rd_ptr[4]) && (wr_ptr_transferred[3:0] == rd_ptr[3:0]);
assign full = (wr_ptr[4] != rd_ptr_transferred[4]) && (wr_ptr[3:0] == rd_ptr_transferred[3:0]);
assign rd_data = data[rd_ptr[3:0]];

endmodule

module norm_to_gray (
    input [4:0] in,
    output reg [4:0] out
);

always @(*) begin
    out = in ^ (in >> 1);
end

endmodule

module gray_to_norm (
    input [4:0] in,
    output reg [4:0] out
);

always @(*) begin
    out[4] = in[4];
    for (int i=3; i>=0; i--) begin
        out[i] = out[i+1] ^ in[i];
    end
end

endmodule