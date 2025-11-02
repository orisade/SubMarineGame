/*
 * Matrix Memory Module
 * 2-bit wide memory with dual input ports and arbiter
 */

module matrix_mem #(parameter WIDTH = 6)(
    input clk,
    input rstn,

    input [2:0] in1_x,
    input [2:0] in1_y,
    input in1_wr_en,
    input [1:0] in1_data_in,
    input in1_data_in_valid,

    input [2:0] in2_x,
    input [2:0] in2_y,
    input in2_wr_en,
    input [1:0] in2_data_in,
    input in2_data_in_valid,

    input in_sel,

    input [1:0] init_select,

    output reg [1:0] data_out,
    output reg empty,
    output reg data_out_valid
);

reg [1:0] matrix [WIDTH*WIDTH-1:0];
wire [5:0] index;
wire [2:0] x, y;
wire wr_en;
wire [1:0] data_in;
wire data_in_valid;

assign x = in_sel ? in2_x : in1_x;
assign y = in_sel ? in2_y : in1_y;
assign wr_en = in_sel ? in2_wr_en : in1_wr_en;
assign data_in = in_sel ? in2_data_in : in1_data_in;
assign data_in_valid = in_sel ? in2_data_in_valid : in1_data_in_valid;

assign index = x*WIDTH + y;

// Check if all submarine bits (bit 0) are cleared
integer k;
always @(*) begin
    empty = 1'b1;
    for (k = 0; k < WIDTH*WIDTH; k = k + 1) begin
        if (matrix[k][0]) empty = 1'b0;
    end
end

// Auxiliary variables for wave viewer debugging - display matrix as 2D array
reg [1:0] matrix_display [0:WIDTH-1][0:WIDTH-1];
integer row, col;
always @(*) begin
    for (row = 0; row < WIDTH; row = row + 1) begin
        for (col = 0; col < WIDTH; col = col + 1) begin
            matrix_display[row][col] = matrix[row*WIDTH + col];
        end
    end
end

// Individual row signals for easier wave viewing
wire [1:0] row0 [0:WIDTH-1];
wire [1:0] row1 [0:WIDTH-1];
wire [1:0] row2 [0:WIDTH-1];
wire [1:0] row3 [0:WIDTH-1];
wire [1:0] row4 [0:WIDTH-1];
wire [1:0] row5 [0:WIDTH-1];

// Flattened row signals for wave viewer
wire [11:0] row0_flat, row1_flat, row2_flat, row3_flat, row4_flat, row5_flat;

genvar i;
generate
    for (i = 0; i < WIDTH; i = i + 1) begin : row_signals
        assign row0[i] = matrix_display[0][i];
        assign row1[i] = matrix_display[1][i];
        assign row2[i] = matrix_display[2][i];
        assign row3[i] = matrix_display[3][i];
        assign row4[i] = matrix_display[4][i];
        assign row5[i] = matrix_display[5][i];
    end
endgenerate

assign row0_flat = {row0[5], row0[4], row0[3], row0[2], row0[1], row0[0]};
assign row1_flat = {row1[5], row1[4], row1[3], row1[2], row1[1], row1[0]};
assign row2_flat = {row2[5], row2[4], row2[3], row2[2], row2[1], row2[0]};
assign row3_flat = {row3[5], row3[4], row3[3], row3[2], row3[1], row3[0]};
assign row4_flat = {row4[5], row4[4], row4[3], row4[2], row4[1], row4[0]};
assign row5_flat = {row5[5], row5[4], row5[3], row5[2], row5[1], row5[0]};

// Individual scalar signals for each matrix position (better wave viewer compatibility)
wire [1:0] m00, m01, m02, m03, m04, m05;
wire [1:0] m10, m11, m12, m13, m14, m15;
wire [1:0] m20, m21, m22, m23, m24, m25;
wire [1:0] m30, m31, m32, m33, m34, m35;
wire [1:0] m40, m41, m42, m43, m44, m45;
wire [1:0] m50, m51, m52, m53, m54, m55;

assign m00 = matrix_display[0][0]; assign m01 = matrix_display[0][1]; assign m02 = matrix_display[0][2];
assign m03 = matrix_display[0][3]; assign m04 = matrix_display[0][4]; assign m05 = matrix_display[0][5];
assign m10 = matrix_display[1][0]; assign m11 = matrix_display[1][1]; assign m12 = matrix_display[1][2];
assign m13 = matrix_display[1][3]; assign m14 = matrix_display[1][4]; assign m15 = matrix_display[1][5];
assign m20 = matrix_display[2][0]; assign m21 = matrix_display[2][1]; assign m22 = matrix_display[2][2];
assign m23 = matrix_display[2][3]; assign m24 = matrix_display[2][4]; assign m25 = matrix_display[2][5];
assign m30 = matrix_display[3][0]; assign m31 = matrix_display[3][1]; assign m32 = matrix_display[3][2];
assign m33 = matrix_display[3][3]; assign m34 = matrix_display[3][4]; assign m35 = matrix_display[3][5];
assign m40 = matrix_display[4][0]; assign m41 = matrix_display[4][1]; assign m42 = matrix_display[4][2];
assign m43 = matrix_display[4][3]; assign m44 = matrix_display[4][4]; assign m45 = matrix_display[4][5];
assign m50 = matrix_display[5][0]; assign m51 = matrix_display[5][1]; assign m52 = matrix_display[5][2];
assign m53 = matrix_display[5][3]; assign m54 = matrix_display[5][4]; assign m55 = matrix_display[5][5];

always @(posedge clk or negedge rstn) begin
    if (~rstn) begin
        data_out <= 2'b00;
        data_out_valid <= 1'b0;
        case (init_select)
            2'b00: begin
                    for (integer i = 0; i < WIDTH*WIDTH; i = i + 1) begin
                        matrix[i] <= {1'b0, (36'b000011_000001_000001_110010_000000_101100 >> i) & 1'b1};
                    end
                   end
            2'b01: begin
                    for (integer i = 0; i < WIDTH*WIDTH; i = i + 1) begin
                        matrix[i] <= {1'b0, (36'b001010_000001_000000_010111_000000_101100 >> i) & 1'b1};
                    end
                   end
            2'b10: begin
                    for (integer i = 0; i < WIDTH*WIDTH; i = i + 1) begin
                        matrix[i] <= {1'b0, (36'b010000_101000_000101_000000_101010_000010 >> i) & 1'b1};
                    end
                   end
            2'b11: begin
                    for (integer i = 0; i < WIDTH*WIDTH; i = i + 1) begin
                        matrix[i] <= {1'b0, (36'b000010_100000_001001_010100_100001_000100 >> i) & 1'b1};
                    end
                   end
        endcase

    end else begin
        data_out_valid <= 1'b0;  // Default to invalid
        
        if (data_in_valid && index < (WIDTH*WIDTH)) begin 
            if (wr_en) begin
                matrix[index] <= data_in;
            end
            data_out <= matrix[index];
            data_out_valid <= 1'b1;  // Signal valid output
        end
    end
end

endmodule
