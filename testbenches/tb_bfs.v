`timescale 1ns / 1ps

module tb_bfs;
    parameter WIDTH = 6;
    
    reg clk, rstn, bfs_start;
    reg [2:0] x, y;
    reg [1:0] mem_rd_data;
    reg mem_ready;
    wire [2:0] mem_addr_x, mem_addr_y;
    wire [1:0] mem_wr_data;
    wire mem_wr_en, mem_in_valid, bfs_sink, bfs_done;
    
    bfs #(.WIDTH(WIDTH)) uut (
        .clk(clk), .rstn(rstn), .bfs_start(bfs_start),
        .x(x), .y(y),
        .mem_addr_x(mem_addr_x), .mem_addr_y(mem_addr_y),
        .mem_wr_data(mem_wr_data), .mem_rd_data(mem_rd_data),
        .mem_wr_en(mem_wr_en), .mem_in_valid(mem_in_valid),
        .mem_ready(mem_ready),
        .bfs_sink(bfs_sink), .bfs_done(bfs_done)
    );
    
    always #5 clk = ~clk;
    
    // Simple memory model
    reg [1:0] test_mem [0:35];
    
    // Flattened memory signals for wave viewer
    wire [71:0] mem_flat;
    wire [11:0] row0_mem, row1_mem, row2_mem, row3_mem, row4_mem, row5_mem;
    
    assign mem_flat = {test_mem[35], test_mem[34], test_mem[33], test_mem[32], test_mem[31], test_mem[30],
                       test_mem[29], test_mem[28], test_mem[27], test_mem[26], test_mem[25], test_mem[24],
                       test_mem[23], test_mem[22], test_mem[21], test_mem[20], test_mem[19], test_mem[18],
                       test_mem[17], test_mem[16], test_mem[15], test_mem[14], test_mem[13], test_mem[12],
                       test_mem[11], test_mem[10], test_mem[9], test_mem[8], test_mem[7], test_mem[6],
                       test_mem[5], test_mem[4], test_mem[3], test_mem[2], test_mem[1], test_mem[0]};
    
    assign row0_mem = {test_mem[5], test_mem[4], test_mem[3], test_mem[2], test_mem[1], test_mem[0]};
    assign row1_mem = {test_mem[11], test_mem[10], test_mem[9], test_mem[8], test_mem[7], test_mem[6]};
    assign row2_mem = {test_mem[17], test_mem[16], test_mem[15], test_mem[14], test_mem[13], test_mem[12]};
    assign row3_mem = {test_mem[23], test_mem[22], test_mem[21], test_mem[20], test_mem[19], test_mem[18]};
    assign row4_mem = {test_mem[29], test_mem[28], test_mem[27], test_mem[26], test_mem[25], test_mem[24]};
    assign row5_mem = {test_mem[35], test_mem[34], test_mem[33], test_mem[32], test_mem[31], test_mem[30]};
    
    always @(posedge clk) begin
        if (mem_in_valid) begin
            if (mem_wr_en)
                test_mem[mem_addr_y*WIDTH + mem_addr_x] <= mem_wr_data;
            mem_rd_data <= test_mem[mem_addr_y*WIDTH + mem_addr_x];
            mem_ready <= 1;
        end else begin
            mem_ready <= 0;
        end
    end
    
    initial begin
        $dumpfile("vcd/tb_bfs.vcd");
        $dumpvars(0, tb_bfs);
        
        clk = 0; rstn = 0; bfs_start = 0; mem_ready = 0;
        
        // Initialize test pattern
        for (integer i = 0; i < 36; i = i + 1) test_mem[i] = 2'b00;
        test_mem[7] = 2'b01;  // (1,1)
        test_mem[8] = 2'b01;  // (2,1)
        test_mem[13] = 2'b01; // (1,2)
        
        #10 rstn = 1;
        
        // Test 1: Multi-cell boat (should not sink)
        $display("=== Test 1: Multi-cell boat ===");
        #10 x = 1; y = 1; bfs_start = 1;
        wait(bfs_done);
        #10 bfs_start = 0;
        $display("Multi-cell boat result: sink=%b (expected: 0)", bfs_sink);
        
        #10 x = 2; y = 1; bfs_start = 1;
        wait(bfs_done);
        #10 bfs_start = 0;
        $display("Multi-cell boat result: sink=%b (expected: 0)", bfs_sink);
                
        #10 x = 1; y = 2; bfs_start = 1;
        wait(bfs_done);
        #10 bfs_start = 0;
        $display("Multi-cell boat result: sink=%b (expected: 1)", bfs_sink);
        
        // Test 2: Single-cell boat (should sink)
        $display("=== Test 2: Single-cell boat ===");
        // Clear memory and set single cell
        for (integer i = 0; i < 36; i = i + 1) test_mem[i] = 2'b00;
        test_mem[14] = 2'b01; // (2,2) - isolated cell
        
        #10 x = 2; y = 2; bfs_start = 1;
        wait(bfs_done);
        #10 bfs_start = 0;
        $display("Single-cell boat result: sink=%b (expected: 1)", bfs_sink);
        
        // Test 3: Reset functionality
        $display("=== Test 3: Reset test ===");
        // Set up another multi-cell boat
        for (integer i = 0; i < 36; i = i + 1) test_mem[i] = 2'b00;
        test_mem[20] = 2'b01; // (2,3)
        test_mem[21] = 2'b01; // (3,3)
        
        // Start BFS operation
        #10 x = 2; y = 3; bfs_start = 1;
        #5; // Let it start processing
        
        // Apply reset during operation
        rstn = 0;
        #10 rstn = 1;
        bfs_start = 0;
        
        // Test same configuration after reset
        #10 x = 2; y = 3; bfs_start = 1;
        wait(bfs_done);
        #10 bfs_start = 0;
        $display("After reset result: sink=%b (expected: 0)", bfs_sink);
        
        #10 x = 3; y = 3; bfs_start = 1;
        wait(bfs_done);
        #10 bfs_start = 0;
        $display("After reset result: sink=%b (expected: 1)", bfs_sink);
        
        $display("=== All BFS tests completed ===");
        #40;
        $finish;
    end
endmodule
