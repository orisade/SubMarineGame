/*
 * Owner: ossade
 * Date: 2 Sep 2025
 *
 *  Description: sub marine game
 *  input init_select to select a pre-defined sub marines map
 *  input x,y corrdination with cord_valid to indicate valid cordinations
 *  when hit/sinked a submarine will get proper pulse indication
 *  when all submarines are senk - done "level" pin will be set
 *  output will be cleared when facing a reset / init_select 
 * 
 * 
 *  Limitations: will ignore duplicated selection of the same coordination
 *
 *  Open BUGs:
 *  001: sink logic is not working well as we will get sink for [1,1,1] --> [1,0,1] --> [1,0,0] !
 *       action: sink is disabled for now (const 1'b0)
 *
 *  Timing: after a coordination send, need to wait for at least 2 cycles to send another cord
 *          this is because after sending the cord, the busy wait may rise and if it will, we will know it 
 *          only in the next cycle so this is 2 cycles 
 */
`define DISABLE_SINK

module submarine (
    input clk,
    input rstn,

    input [1:0] init_select,
    input select_valid,

    input [2:0] x,
    input [2:0] y,
    input cord_valid,

    output reg busy,
    output reg hit,
    output reg sink,
    output reg done
);

localparam WIDTH = 6;
reg mem_cmd_valid;
reg is_read;
reg matrix_mem_data_in;
wire matrix_mem_data_out;
wire matrix_mem_data_out_valid;
wire matrix_mem_data_in_ready;

localparam WAIT_FOR_COR = 3'b000;
localparam CHECK_COR = 3'b001;
localparam CHECK_SINK = 3'b010;
localparam CHECK_DONE = 3'b011;
localparam CLEAR_BIT = 3'b100;
localparam CHECK_DONE_FIRST = 3'b101;

localparam DELAY = 3'b110;
localparam WAIT_FOR_MEM = 3'b111;
reg [2:0] state;
reg [2:0] next_state;

reg [2:0] saved_x;
reg [2:0] saved_y;
reg saved_value;
reg after_delay;

wire [5:0] index;

assign index = x*WIDTH + y;

matrix_mem #(.WIDTH(WIDTH)) matrix (
    .clk(clk),
    .rstn(rstn),
    .x(saved_x),
    .y(saved_y),
    .read_write_en(mem_cmd_valid),
    .is_read(is_read),
    .data_in(matrix_mem_data_in),

    .init_select(init_select),
    .select_valid(select_valid),

    .data_out(matrix_mem_data_out),
    .data_out_valid(matrix_mem_data_out_valid),
    .data_in_ready(matrix_mem_data_in_ready)
);


/*
wire some_exists;

wire [2:0] x_upper;
wire [2:0] x_lower;
wire [2:0] y_upper;
wire [2:0] y_lower;
assign x_upper = saved_x >= WIDTH ? saved_x : saved_x + 1;
assign x_lower = saved_x == 0 ?     saved_x : saved_x - 1;
assign y_upper = saved_y >= WIDTH ? saved_y : saved_y + 1;
assign y_lower = saved_y == 0 ?     saved_y : saved_y - 1; 
assign some_exists = matrix[x_upper * WIDTH + saved_y] | 
                     matrix[x_lower * WIDTH + saved_y] | 
                     matrix[saved_x * WIDTH + y_upper] | 
                     matrix[saved_x * WIDTH + y_lower];
*/


reg [5:0] loop_i;

always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        busy <= 1'b0;
        hit <= 1'b0;
        sink <= 1'b0;
        done <= 1'b0;
        state <= WAIT_FOR_COR;
        saved_x <= 2'b0;
        saved_y <= 2'b0;
        loop_i <= {WIDTH{1'b0}};
        mem_cmd_valid <= 1'b0;
        after_delay <= 1'b0;

    end else begin
        if (select_valid) begin
            hit <= 1'b0;
            sink <= 1'b0;
            done <= 1'b0;
            state <= WAIT_FOR_COR;
            next_state <= WAIT_FOR_COR;
            saved_x <= 2'b0;
            saved_y <= 2'b0;
            loop_i <= {WIDTH{1'b0}};
        end else begin
            case (state) 
                WAIT_FOR_COR : begin
                    hit <= 1'b0;
                    sink <= 1'b0;
                    done <= 1'b0;
                    busy <= 1'b0;
                    if (cord_valid && (index < WIDTH*WIDTH)) begin 
                        saved_x <= x;
                        saved_y <= y;
                        mem_cmd_valid <= 1'b1;
                        is_read <= 1'b1;
                        busy <= 1'b1;
                        
                        state <= WAIT_FOR_MEM;
                        next_state <= CHECK_COR;
                    end
                end
                CHECK_COR : begin
                    if (matrix_mem_data_out == 1'b1) begin
                        /* clear bit */
                        is_read <= 1'b0;
                        mem_cmd_valid <= 1'b1;
                        matrix_mem_data_in <= 1'b0;
                        saved_value <= 1'b0;

                        state <= WAIT_FOR_MEM;
                        next_state <= CHECK_DONE_FIRST;
                    end else begin
                        busy <= 1'b0;
                        state <= WAIT_FOR_COR;
                    end
                end

                CHECK_DONE_FIRST : begin
                    loop_i <= 0;
                    /* start from the beginning */
                    saved_x <= 1'b0;
                    saved_y <= 1'b0;
                    state <= CHECK_DONE;
                end

                // CHECK_SINK : begin
                //     state <= WAIT_FOR_COR;
                //     busy <= 1'b0;
                //     if (~some_exists) begin
                //         state <= CHECK_DONE;    /* will override the WAIT_FOR_COR */
                //         busy <= 1'b1;           /* will override the 1'b0 */
                //     end else begin
                //         hit <= 1'b1;            /* return to WAIT_FOR_COR with this status */
                //     end
                // end
                CHECK_DONE : begin
                    /* need to check that all of the map is 1'b0 .. */
                    if (loop_i == (WIDTH*WIDTH-1)) begin
                        /* send status */
                        done <= 1'b1;
                    end else if (saved_value == 1'b0) begin
                        loop_i <= loop_i + 1;
                        saved_x <= (saved_x + 1) % WIDTH;
                        saved_y <= saved_y + (saved_x == WIDTH-1);
                        mem_cmd_valid <= 1'b1;
                        is_read <= 1'b1;
                        state <= WAIT_FOR_MEM;
                        next_state <= CHECK_DONE;
                    end else begin
                        /* stop looping because we found 1'b1 */
                        state <= WAIT_FOR_COR;
                        busy <= 1'b0;
                        loop_i <= 0;
                        mem_cmd_valid <= 1'b0;
                        is_read <= 1'b0;
                        /* send status */
                        sink <= 1'b1; //disabled below: BUG 001
                        `ifdef DISABLE_SINK
                        sink <= 1'b0;
                        `endif
                    end
                end
                WAIT_FOR_MEM: begin
                    mem_cmd_valid <= 1'b0;  /* pulse */
                    if (is_read && matrix_mem_data_out_valid) begin
                        if (after_delay) begin
                            state <= next_state;
                            after_delay <= 1'b0;
                            saved_value <= matrix_mem_data_out;
                        end else begin 
                            state <= DELAY;
                        end
                    end else if (~is_read && matrix_mem_data_in_ready) begin
                        if (after_delay) begin
                            state <= next_state;
                            after_delay <= 1'b0;
                            matrix_mem_data_in <= 1'b0; /* clear the memory */
                        end else begin
                            state <= DELAY;
                        end
                    end
                end

                DELAY: begin
                    after_delay <= 1'b1;
                    state <= WAIT_FOR_MEM;
                end

                default: 
                    state <= WAIT_FOR_COR;
            endcase
        end
    end
end

endmodule


module matrix_mem #(parameter WIDTH = 6)(
    input clk,
    input rstn,

    input [2:0] x,
    input [2:0] y,
    input read_write_en,
    input is_read,
    input data_in,

    input [1:0] init_select,
    input select_valid,

    output reg data_out,
    output reg data_out_valid,
    output reg data_in_ready
);

reg [WIDTH*WIDTH - 1:0] matrix;
wire [5:0] index;

assign index = x*WIDTH + y;

always @(posedge clk or negedge rstn) begin
    if (~rstn) begin
        matrix <= {(WIDTH*WIDTH-1){1'b0}};
        data_in_ready <= 1'b0;

    end else begin 
        data_out_valid <= 1'b1;
        data_in_ready <= 1'b1;  /* set to 1'b1 1 cycle after each write */
        if (select_valid) begin
            case (init_select)
                2'b00: matrix <= 36'b000011_000001_000001_110010_000000_101100;
                /*
                matrix[x][WIDTH-1], matrix[x][WIDTH-2] ..
                '{0,0,0,0,1,1},
                '{0,0,0,0,0,1},
                '{0,0,0,0,0,1},     .
                '{1,1,0,0,1,0},     .
                '{0,0,0,0,0,0},     matrix[1][y]
                '{1,0,1,1,0,0}      matrix[0][y]
                */

                2'b01: matrix <= 36'b001010_000001_000000_010111_000000_101100;
                /*
                '{0,0,1,0,1,0}, 
                '{0,0,0,0,0,1}, 
                '{0,0,0,0,0,0}, 
                '{0,1,0,1,1,1}, 
                '{0,0,0,0,0,0}, 
                '{1,0,1,1,0,0}
                */

                2'b10: matrix <= 36'b010000_101000_000101_000000_101010_000010;
                /*
                '{0,1,0,0,0,0}, 
                '{1,0,1,0,0,0}, 
                '{0,0,0,1,0,1}, 
                '{0,0,0,0,0,0}, 
                '{1,0,1,0,1,0}, 
                '{0,0,0,0,1,0}
                */

                2'b11: matrix <= 36'b000010_100000_001001_010100_100001_000100;
                /*
                '{0,0,0,0,1,0}, 
                '{1,0,0,0,0,0}, 
                '{0,0,1,0,0,1}, 
                '{0,1,0,1,0,0}, 
                '{1,0,0,0,0,1}, 
                '{0,0,0,1,0,0}
                */

                /* no default needed since all 4 options are covered */
            endcase
        end else if (read_write_en && (index < (WIDTH*WIDTH))) begin 
            if (is_read) begin
                data_out <= matrix[index];
                data_out_valid <= 1'b0; /* simulate time */
            end else begin
                matrix[index] <= data_in;
                data_in_ready <= 1'b0;  /* simulate time */
            end
        end
    end
end


endmodule