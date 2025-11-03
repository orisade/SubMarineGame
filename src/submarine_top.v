/*
 * Submarine Game Top Module
 * Connects game engine, BFS, and memory with proper arbitration
 */

module submarine_top (
    input clk,
    input rstn,

    input [1:0] init_select,

    input [2:0] x,
    input [2:0] y,
    input cord_valid,

    output busy,
    output hit,
    output sink,
    output done
);

localparam WIDTH = 6;

// Game engine signals
wire [2:0] game_mem_x, game_mem_y;
wire game_mem_data_in_valid;
wire [1:0] mem_data_out;
wire mem_empty;
wire mem_data_out_valid;

// BFS signals
wire [2:0] bfs_mem_addr_x, bfs_mem_addr_y;
wire bfs_mem_wr_en;
wire [1:0] bfs_mem_wr_data;
wire bfs_mem_in_valid;
wire bfs_start, bfs_sink, bfs_done;

// Memory arbitration
wire mem_sel;
assign mem_sel = bfs_start;

game_engine game (
    .clk(clk),
    .rstn(rstn),
    .x(x),
    .y(y),
    .cord_valid(cord_valid),
    .busy(busy),
    .hit(hit),
    .sink(sink),
    .done(done),
    
    // Memory interface
    .mem_x(game_mem_x),
    .mem_y(game_mem_y),
    .mem_data_in_valid(game_mem_data_in_valid),
    .mem_data_out(mem_data_out),
    .mem_data_out_valid(mem_data_out_valid),
    .mem_empty(mem_empty),
    
    // BFS interface
    .bfs_start(bfs_start),
    .bfs_sink(bfs_sink),
    .bfs_done(bfs_done)
);

bfs #(.WIDTH(WIDTH)) bfs_inst (
    .clk(clk),
    .rstn(rstn),
    .x(game_mem_x),
    .y(game_mem_y),
    
    // Memory interface
    .mem_addr_x(bfs_mem_addr_x),
    .mem_addr_y(bfs_mem_addr_y),
    .mem_wr_en(bfs_mem_wr_en),
    .mem_wr_data(bfs_mem_wr_data),
    .mem_in_valid(bfs_mem_in_valid),
    .mem_rd_data(mem_data_out),
    .mem_ready(mem_data_out_valid),
    
    .bfs_start(bfs_start),
    .bfs_sink(bfs_sink),
    .bfs_done(bfs_done)
);

matrix_mem #(.WIDTH(WIDTH)) memory (
    .clk(clk),
    .rstn(rstn),
    
    // Input 1: Game engine (read-only)
    .in1_x(game_mem_x),
    .in1_y(game_mem_y),
    .in1_wr_en(1'b0),
    .in1_data_in(2'b00),
    .in1_data_in_valid(game_mem_data_in_valid),
    
    // Input 2: BFS
    .in2_x(bfs_mem_addr_x),
    .in2_y(bfs_mem_addr_y),
    .in2_wr_en(bfs_mem_wr_en),
    .in2_data_in(bfs_mem_wr_data),
    .in2_data_in_valid(bfs_mem_in_valid),
    
    .in_sel(mem_sel),
    
    .init_select(init_select),
    
    .data_out(mem_data_out),
    .empty(mem_empty),
    .data_out_valid(mem_data_out_valid)
);

endmodule
