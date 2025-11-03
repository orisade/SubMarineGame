`timescale 1ns / 1ps

module tb_matrix_mem;
    parameter WIDTH = 6;
    
    reg clk, rstn;
    reg [2:0] in1_x, in1_y, in2_x, in2_y;
    reg [1:0] in1_data_in, in2_data_in, init_select;
    reg in1_wr_en, in2_wr_en, in1_data_in_valid, in2_data_in_valid, in_sel;
    wire [1:0] data_out;
    wire empty, data_out_valid;
    
    matrix_mem #(.WIDTH(WIDTH)) uut (
        .clk(clk), .rstn(rstn),
        .in1_x(in1_x), .in1_y(in1_y), .in1_wr_en(in1_wr_en),
        .in1_data_in(in1_data_in), .in1_data_in_valid(in1_data_in_valid),
        .in2_x(in2_x), .in2_y(in2_y), .in2_wr_en(in2_wr_en),
        .in2_data_in(in2_data_in), .in2_data_in_valid(in2_data_in_valid),
        .in_sel(in_sel), .init_select(init_select),
        .data_out(data_out), .empty(empty), .data_out_valid(data_out_valid)
    );
    
    always #5 clk = ~clk;
    
    initial begin
        $dumpfile("vcd/tb_matrix_mem.vcd");
        $dumpvars(0, tb_matrix_mem);
        
        clk = 0; rstn = 0; in1_wr_en = 0; in2_wr_en = 0; in_sel = 0;
        in1_data_in_valid = 0; in2_data_in_valid = 0; init_select = 0;
        #10 rstn = 1;
        
        // Test port 1 write
        in1_x = 1; in1_y = 1; in1_data_in = 2'b01; 
        in1_wr_en = 1; in1_data_in_valid = 1;
        #10 in1_wr_en = 0;
        
        // Test port 1 read (keep data_in_valid high for read)
        #10;
        if (data_out_valid && data_out == 2'b01) $display("Port 1 test PASSED");
        else $display("Port 1 read: expected 01, got %b (valid=%b)", data_out, data_out_valid);
        in1_data_in_valid = 0;
        
        // Test port 2 with arbiter
        in_sel = 1;
        in2_x = 2; in2_y = 2; in2_data_in = 2'b10;
        in2_wr_en = 1; in2_data_in_valid = 1;
        #10 in2_wr_en = 0;
        
        // Test port 2 read
        #10;
        if (data_out_valid && data_out == 2'b10) $display("Port 2 test PASSED");
        else $display("Port 2 read: expected 10, got %b (valid=%b)", data_out, data_out_valid);
        
        $display("Matrix memory verification COMPLETED");
        $finish;
    end
endmodule
