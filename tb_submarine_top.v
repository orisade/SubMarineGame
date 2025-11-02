`timescale 1ns / 1ps

module tb_submarine_top;
    reg clk, rstn, cord_valid;
    reg [2:0] x, y;
    reg [1:0] init_select;
    wire busy, hit, sink, done;
    
    submarine_top uut (
        .clk(clk), .rstn(rstn), .cord_valid(cord_valid),
        .x(x), .y(y), .init_select(init_select),
        .busy(busy), .hit(hit), .sink(sink), .done(done)
    );
    
    always #5 clk = ~clk;
    
    initial begin
        $dumpfile("tb_submarine_top.vcd");
        $dumpvars(0, tb_submarine_top);
        
        clk = 0; rstn = 0; cord_valid = 0; init_select = 0;
        #10 rstn = 1;
        
        // Test known hit
        x = 3; y = 0; cord_valid = 1;
        #10 cord_valid = 0;
        #5;
        
        wait(!busy);
        if (!hit) $error("Expected hit but got miss");
        #10;
        
        // Test known miss
        x = 0; y = 0; cord_valid = 1;
        #10 cord_valid = 0;
        
        #5;
        wait(!busy);
        if (hit) $error("Expected miss but got hit");
        
        $display("Submarine top verification PASSED");
        $finish;
    end
endmodule
