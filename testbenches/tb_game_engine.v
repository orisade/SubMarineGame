`timescale 1ns / 1ps

module tb_game_engine;
    reg clk, rstn, cord_valid, mem_empty;
    reg [2:0] x, y;
    reg [1:0] mem_data_out;
    reg mem_data_out_valid, bfs_sink, bfs_done;
    wire [2:0] mem_x, mem_y;
    wire mem_data_in_valid, bfs_start;
    wire busy, hit, sink, done;
    
    game_engine uut (
        .clk(clk), .rstn(rstn), .cord_valid(cord_valid),
        .x(x), .y(y), .mem_empty(mem_empty),
        .mem_x(mem_x), .mem_y(mem_y),
        .mem_data_out(mem_data_out), .mem_data_in_valid(mem_data_in_valid),
        .mem_data_out_valid(mem_data_out_valid),
        .bfs_start(bfs_start), .bfs_sink(bfs_sink), .bfs_done(bfs_done),
        .busy(busy), .hit(hit), .sink(sink), .done(done)
    );
    
    always #5 clk = ~clk;
    
    initial begin
        clk = 0; rstn = 0; cord_valid = 0; mem_empty = 0;
        mem_data_out_valid = 1; bfs_sink = 0; bfs_done = 0;
        
        #10 rstn = 1;
        
        // Test hit
        x = 2; y = 2; mem_data_out = 2'b01; cord_valid = 1;
        #10 cord_valid = 0;
        #20 bfs_sink = 0; bfs_done = 1;
        #10 bfs_done = 0; bfs_sink = 0;
        
        wait(!busy);
        if (!hit) $error("Hit test failed");
        
        // Test miss
        #10 rstn = 0; #10 rstn = 1;
        x = 0; y = 0; mem_data_out = 2'b00; cord_valid = 1;
        #10 cord_valid = 0;

        #20 bfs_sink = 1; bfs_done = 1;
        #10 bfs_done = 0; bfs_sink = 0;
        
        wait(!busy);
        if (hit) $error("Miss test failed");
        
        $display("Game engine verification PASSED");
        $finish;
    end
endmodule
