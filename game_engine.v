/*
 * Owner: ossade
 * Date: 2 Sep 2025
 *
 * Description: submarine game engine
 *  input init_select to select a pre-defined sub marines map
 *  input x,y coordination with cord_valid to indicate valid coordinations
 *  when hit/sinked a submarine will get proper pulse indication
 *  when all submarines are sunk - done "level" pin will be set
 *  output will be cleared when facing a reset / init_select 
 * 
 * Limitations: will ignore duplicated selection of the same coordination
 *
 * Timing: after sending a coordination need to wait for 2 clock cycles
 *         then wait till the busy line is low to continue for the next coordination
 */

module game_engine (
    input clk,
    input rstn,

    input [2:0] x,
    input [2:0] y,
    input cord_valid,

    output busy,
    output reg hit,
    output reg sink,
    output reg done,

    // Memory interface
    output reg [2:0] mem_x,
    output reg [2:0] mem_y,
    output reg mem_data_in_valid,
    input [1:0] mem_data_out,
    input mem_data_out_valid,
    input mem_empty,

    // BFS interface
    output reg bfs_start,
    input bfs_sink,
    input bfs_done
);

localparam WIDTH = 6;

wire [5:0] index;
assign index = x*WIDTH + y;

reg [2:0] state;
reg [2:0] next_state;

localparam WAIT_FOR_COR = 3'b000;
localparam CHECK_COR = 3'b001;
localparam CHECK_SINK = 3'b010;
localparam DONE = 3'b011;
localparam DELAY = 3'b110;

reg [8*8-1:0] state_name;
always @(state) begin
    case (state) 
        WAIT_FOR_COR : state_name = "W_CORD";
        CHECK_COR : state_name = "C_CORD";
        CHECK_SINK : state_name = "C_SINK";
        DONE : state_name = "DONE";
        DELAY: state_name = "DELAY";
        default: state_name = "UNKNOWN";
    endcase
end

assign busy = (state != WAIT_FOR_COR) && (state != DONE);

always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        hit <= 1'b0;
        sink <= 1'b0;
        done <= 1'b0;
        state <= WAIT_FOR_COR;
        mem_x <= 3'b0;
        mem_y <= 3'b0;
        mem_data_in_valid <= 1'b0;
        bfs_start <= 1'b0;
    end else begin
        case (state) 
            WAIT_FOR_COR : begin
                hit <= 1'b0;
                sink <= 1'b0;
                done <= 1'b0;
                if (cord_valid && (index < WIDTH*WIDTH)) begin 
                    mem_x <= x;
                    mem_y <= y;
                    mem_data_in_valid <= 1'b1;
                    
                    state <= DELAY;
                    next_state <= CHECK_COR;
                end
            end
            CHECK_COR : begin
                if (mem_data_out[0] == 1'b1) begin
                    state <= CHECK_SINK;
                end else begin
                    state <= WAIT_FOR_COR;
                end
            end

            CHECK_SINK : begin
                bfs_start <= 1'b1;
                if (bfs_done) begin 
                    if (mem_empty) begin
                        state <= DONE;
                        done <= 1'b1;
                    end else begin
                        state <= WAIT_FOR_COR;
                        sink <= ~mem_empty & bfs_sink;
                    end
                    hit <= bfs_sink ? 1'b0 : 1'b1;
                    bfs_start <= 1'b0;
                end
            end

            DONE : begin
                done <= 1'b1;
                // Stay in DONE state until reset
            end

            DELAY: begin
                mem_data_in_valid <= 1'b0;  // Clear valid signal
                if (mem_data_out_valid) begin
                    state <= next_state;
                end
            end

            default: 
                state <= WAIT_FOR_COR;
        endcase
    end
end

endmodule
