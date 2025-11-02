/*
 * Owner: ossade
 * Date: 2 Sep 2025
 *
 * Description: sub marine game
 *  input init_select to select a pre-defined sub marines map
 *  input x,y corrdination with cord_valid to indicate valid cordinations
 *  when hit/sinked a submarine will get proper pulse indication
 *  when all submarines are senk - done "level" pin will be set
 *  output will be cleared when facing a reset / init_select 
 * 
 * 
 * Limitations: will ignore duplicated selection of the same coordination
 *
 * Timing: after sending a coordination need to wait for 2 clock cycles (so the module could sample the data and change the busy line)
 *         then wait till the busy line is low to continue for the next coordination - or send the data on negedge and sample the busy on negedge
*/

module submarine (
    input clk,
    input rstn,

    input [1:0] init_select,
    input select_valid,

    input [2:0] x,
    input [2:0] y,
    input cord_valid,

    output busy,
    output reg hit,
    output reg sink,
    output reg done
);

localparam WIDTH = 6;
reg wr_en;
reg matrix_mem_data_in;
wire matrix_mem_data_out;

reg [2:0] mem_x;
reg [2:0] mem_y;
reg saved_value;

wire [5:0] index;

assign index = x*WIDTH + y;

matrix_mem #(.WIDTH(WIDTH)) matrix (
    .clk(clk),
    .rstn(rstn),
    .x(mem_x_muxed),
    .y(mem_y_muxed),
    .wr_en(wr_en),
    .data_in(matrix_mem_data_in),

    .init_select(init_select),
    .select_valid(select_valid),

    .data_out(matrix_mem_data_out)
);

/*
 * BFS
 */
wire [2:0] bfs_mem_x;
wire [2:0] bfs_mem_y;
wire [2:0] mem_x_muxed;
wire [2:0] mem_y_muxed;
assign mem_x_muxed = bfs_start ? bfs_mem_x : mem_x;
assign mem_y_muxed = bfs_start ? bfs_mem_y : mem_y;

/*************************************************************************
 *                            Main Game FSM                              *
 *************************************************************************/
reg [2:0] state;
reg [2:0] next_state;

localparam WAIT_FOR_COR = 3'b000;
localparam CHECK_COR = 3'b001;
localparam CHECK_SINK = 3'b010;
localparam CLEAR_BIT = 3'b011;
localparam CHECK_DONE_FIRST = 3'b100;
localparam CHECK_DONE = 3'b101;

localparam DELAY = 3'b110;

reg [8*8-1:0] state_name;  /* 8 chars string */

always @(state) begin
    case (state) 
        WAIT_FOR_COR : state_name = "W_CORD";
        CHECK_COR : state_name = "C_CORD";
        CHECK_SINK : state_name = "C_SINK";
        CHECK_DONE_FIRST : state_name = "C_DONE1";
        CHECK_DONE : state_name = "C_DONE";

        DELAY: state_name = "DELAY";
    endcase
end

assign busy = (state != WAIT_FOR_COR);
reg [5:0] loop_i;

/* 
 * Matrix
 */
localparam BLANK = 2'b00;
localparam WHITE = 2'b01;
localparam GRAY = 2'b10;

/*
* BFS
*/
wire bfs_sink;
wire bfs_done;
reg bfs_start;

bfs #(.WIDTH(WIDTH)) bfs_instance (
    .clk(clk),
    .rstn(rstn),

    .x(mem_x),
    .y(mem_y),

    .out_mem_x(bfs_mem_x),
    .out_mem_y(bfs_mem_y),
    .mem_data_in(matrix_mem_data_out),
    
    .bfs_start(bfs_start),

    .bfs_sink(bfs_sink),
    .bfs_done(bfs_done)
);


always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        hit <= 1'b0;
        sink <= 1'b0;
        done <= 1'b0;
        state <= WAIT_FOR_COR;
        mem_x <= 2'b0;
        mem_y <= 2'b0;
        loop_i <= {WIDTH{1'b0}};
        matrix_mem_data_in <= 1'b0;
        bfs_start <= 1'b0;
    end else begin
        if (select_valid) begin
            hit <= 1'b0;
            sink <= 1'b0;
            done <= 1'b0;
            state <= WAIT_FOR_COR;
            next_state <= WAIT_FOR_COR;
            mem_x <= 2'b0;
            mem_y <= 2'b0;
            loop_i <= {WIDTH{1'b0}};
            matrix_mem_data_in <= 1'b0;
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
                        wr_en <= 1'b0;
                        
                        state <= DELAY;     /* waiting for memory controller to return the data */
                        next_state <= CHECK_COR;
                    end
                end
                CHECK_COR : begin
                    if (matrix_mem_data_out == 1'b1) begin
                        /* clear bit */
                        wr_en <= 1'b1;
                        matrix_mem_data_in <= 1'b0;

                        state <= DELAY;
                        next_state <= CHECK_SINK;
                    end else begin
                        state <= WAIT_FOR_COR;
                    end
                end

                CHECK_SINK : begin
                    bfs_start <= 1'b1;
                    wr_en <= 1'b0;
                    if (bfs_done) begin 
                        state <= bfs_sink ? CHECK_DONE_FIRST : WAIT_FOR_COR;
                        /* send hit if didn't sink */
                        hit <= bfs_sink ? 1'b0 : 1'b1;  /* same as hit <= ~bfs_sink, but more readable */
                        bfs_start <= 1'b0;
                    end
                end

                CHECK_DONE_FIRST : begin
                    /* start from the beginning */
                    mem_x <= 1'b0;
                    mem_y <= 1'b0;
                    wr_en <= 1'b0;
                    loop_i <= 0;
                    state <= DELAY;
                    next_state <= CHECK_DONE;
                end

                CHECK_DONE : begin
                    /* need to check that all of the map is 1'b0 .. wr_en = 1'b0 constantly */
                    if (loop_i == (WIDTH*WIDTH-1)) begin
                        /* send status */
                        done <= 1'b1;
                    end else if (matrix_mem_data_out == 1'b0) begin
                        loop_i <= loop_i + 1;
                        mem_x <= (mem_x + 1) % WIDTH;
                        mem_y <= mem_y + (mem_x == WIDTH-1);
                        state <= DELAY;
                        next_state <= CHECK_DONE;
                    end else begin
                        /* stop looping because we found 1'b1 */
                        state <= WAIT_FOR_COR;
                        loop_i <= 0;
                        /* send status */
                        sink <= 1'b1; 
                    end
                end

                DELAY: begin
                    state <= next_state;
                end

                default: 
                    state <= WAIT_FOR_COR;
            endcase
        end
    end
end

endmodule
/*************************************************************************
 *                               BFS FSM                                 *
 *************************************************************************/

module bfs #(parameter WIDTH = 5) (
    input clk,
    input rstn,

    input [2:0] x,
    input [2:0] y,

    output [2:0] out_mem_x,
    output [2:0] out_mem_y,
    input mem_data_in,

    input bfs_start,

    output reg bfs_sink,
    output reg bfs_done
);

reg bfs_wr_en;
wire bfs_matrix_data_out;

reg [2:0] bfs_mem_x;
reg [2:0] bfs_mem_y;
reg [2:0] orig_x;
reg [2:0] orig_y;
reg bfs_mem_data_in;

assign out_mem_x = bfs_mem_x;
assign out_mem_y = bfs_mem_y;

matrix_mem #(.WIDTH(WIDTH)) bfs_matrix (
    .clk(clk),
    .rstn(rstn),
    .x(bfs_mem_x),
    .y(bfs_mem_y),
    .wr_en(bfs_wr_en),      
    .data_in(bfs_mem_data_in),

    .init_select(2'b00),   /* not used */
    .select_valid(1'b0),   /* not used */

    .data_out(bfs_matrix_data_out)
);


wire some_exists;

wire [2:0] x_right;
wire [2:0] x_left;
wire [2:0] y_upper;
wire [2:0] y_lower;
assign x_right = orig_x >= WIDTH ? orig_x : orig_x + 1;
assign x_left = orig_x == 0 ?     orig_x : orig_x - 1;
assign y_upper = orig_y >= WIDTH ? orig_y : orig_y + 1;
assign y_lower = orig_y == 0 ?     orig_y : orig_y - 1; 

localparam MAX_SUBMARINE_SIZE = 4; 
localparam MAX_SUBMARINE_SIZE_log2 = 2;
reg [MAX_SUBMARINE_SIZE-1:0][5:0] shift_reg;
reg [3:0] bfs_state;
reg [3:0] bfs_next_state;
localparam BFS_LOAD = 4'b0000;
localparam BFS_START = 4'b0001;
localparam X_R = 4'b0010;
localparam X_L = 4'b0011;
localparam Y_U = 4'b0100;
localparam Y_D = 4'b0101;
localparam CHECK_FOUND = 4'b0110;
localparam BFS_CLEAR = 4'b1000;
localparam BFS_DONE = 4'b1110;
localparam DELAY = 4'b1111;

reg [8*8-1:0] bfs_state_name;
always @(bfs_state) begin
    case (bfs_state) 
        BFS_LOAD : bfs_state_name <= "LOAD";
        BFS_START : bfs_state_name <= "START";
        X_R : bfs_state_name <= "X_R";
        X_L : bfs_state_name <= "X_L";
        Y_U : bfs_state_name <= "Y_U";
        Y_D : bfs_state_name <= "Y_D";
        CHECK_FOUND : bfs_state_name <= "C_FOUND";
        BFS_CLEAR : bfs_state_name <= "CLEAR";
        BFS_DONE : bfs_state_name <= "DONE";
        DELAY : bfs_state_name <= "DELAY";

    endcase
end

wire [5:0] bfs_index;
assign bfs_index = bfs_mem_x*WIDTH + bfs_mem_y;
reg found_gray;
reg found_white;
wire found;
assign found = found_gray | found_white;

reg [2:0] gray_x;
reg [2:0] gray_y;

always @(posedge clk or negedge rstn) begin 
    if (~rstn) begin 
        bfs_sink <= 1'b0;
        bfs_done <= 1'b0;
        bfs_state <= BFS_LOAD;
        bfs_next_state <= BFS_LOAD;
        orig_x <= 3'b000;
        orig_y <= 3'b000;
        found_gray <= 1'b0;
        found_white <= 1'b0;
        bfs_mem_x <= 1'b0;
        bfs_mem_y <= 1'b0;
        bfs_wr_en <= 1'b0;
        bfs_mem_data_in <= 1'b0;
        gray_x <= 3'b000;
        gray_y <= 3'b000;
    end else begin
        case (bfs_state)
            BFS_LOAD : begin
                if (bfs_start) begin
                    /* lock main index */
                    orig_x <= x;
                    orig_y <= y;

                    found_gray <= 1'b0;
                    found_white <= 1'b0;
                    bfs_wr_en <= 1'b0;
                    
                    bfs_state <= BFS_START;
                end
            end
            BFS_START : begin
                bfs_mem_x <= x_left;
                bfs_mem_y <= orig_y;

                bfs_state <= DELAY;
                bfs_next_state <= X_L;
            end
            X_L : begin
                found_gray <= found_gray | bfs_matrix_data_out;
                found_white <= found_white | mem_data_in;
                
                bfs_mem_x <= x_right;
                bfs_mem_y <= orig_y;
                bfs_state <= DELAY;
                bfs_next_state <= X_R;

                if (bfs_matrix_data_out | mem_data_in) begin
                    if (bfs_matrix_data_out)  begin  /* found gray */
                        gray_x <= bfs_mem_x;
                        gray_y <= bfs_mem_y;
                    end
                    if (found)  begin   /* already found 1 -- I'm a cell connecting 2 cells -- cannot remove */
                        bfs_state <= BFS_DONE;
                        bfs_sink <= 1'b0;
                    end
                end
            end
            X_R:  begin
                found_gray <= found_gray | bfs_matrix_data_out;
                found_white <= found_white | mem_data_in;

                bfs_mem_x <= orig_x;
                bfs_mem_y <= y_upper;
                bfs_state <= DELAY;
                bfs_next_state <= Y_U;

                if (bfs_matrix_data_out | mem_data_in) begin
                    if (bfs_matrix_data_out)  begin  /* found gray */
                        gray_x <= bfs_mem_x;
                        gray_y <= bfs_mem_y;
                    end
                    if (found)  begin   /* already found 1 -- I'm a cell connecting 2 cells -- cannot remove */
                        bfs_state <= BFS_DONE;
                        bfs_sink <= 1'b0;
                    end
                end
            end
            Y_U : begin
                found_gray <= found_gray | bfs_matrix_data_out;
                found_white <= found_white | mem_data_in;

                bfs_mem_x <= orig_x;
                bfs_mem_y <= y_lower;
                bfs_state <= DELAY;
                bfs_next_state <= Y_D;

                if (bfs_matrix_data_out | mem_data_in) begin
                    if (bfs_matrix_data_out)  begin  /* found gray */
                        gray_x <= bfs_mem_x;
                        gray_y <= bfs_mem_y;
                    end
                    if (found)  begin/* already found 1 -- I'm a cell connecting 2 cells -- cannot remove */
                        bfs_state <= BFS_DONE;
                        bfs_sink <= 1'b0;
                    end
                end
            end
            Y_D : begin 
                found_gray <= found_gray | bfs_matrix_data_out;
                found_white <= found_white | mem_data_in;
                if (found & (bfs_matrix_data_out | mem_data_in)) begin
                    bfs_sink <= 1'b0;   /* defenetly didn't sink, have 2 cells near me, cannot remote cell */
                    /* return to defaults */
                    bfs_mem_x <= orig_x;
                    bfs_mem_y <= orig_y;
                    bfs_state <= BFS_DONE;
                    bfs_sink <= 1'b0;
                /* found 0 or 1 */
                end begin
                    if (bfs_matrix_data_out)  begin  /* found gray */
                        gray_x <= bfs_mem_x;
                        gray_y <= bfs_mem_y;
                    end
                    bfs_state <= CHECK_FOUND;
                end
            end

            CHECK_FOUND : begin
                /* found 0 or 1 cells only */
                if (found_white) begin
                    /* mark me as gray and go to DONE */
                    bfs_wr_en <= 1'b1;
                    bfs_mem_data_in <= 1'b1;
                    bfs_state <= DELAY;
                    bfs_next_state <= BFS_DONE;
                    bfs_sink <= 1'b0;
                end else if (found_gray) begin
                    /* clear "myself" (in case I'm marked as gray [rec level1+]) and continue
                       recursivly to the next cell */
                    bfs_wr_en <= 1'b1;
                    bfs_mem_data_in <= 1'b0;
                    bfs_state <= DELAY;
                    bfs_mem_x <= orig_x;
                    bfs_mem_y <= orig_y;
                    bfs_next_state <= BFS_CLEAR;
                    bfs_sink <= 1'b0;

                end else begin
                    /* found 0 cells - sink ! - clear "myself" (in case I'm marked as gray [rec level1+]) */
                    bfs_wr_en <= 1'b1;
                    bfs_mem_data_in <= 1'b0;
                    bfs_state <= DELAY;
                    bfs_next_state <= BFS_DONE;
                    bfs_sink <= 1'b1;
                end
            end

            BFS_CLEAR : begin
                orig_x <= gray_x;
                orig_y <= gray_y;
                
                found_gray <= 1'b0;
                found_white <= 1'b0;

                bfs_state <= BFS_START;
                bfs_wr_en <= 1'b0;
            end
            BFS_DONE : begin
                bfs_done <= 1'b1;
                /* check that the module recieved the bfs_done and move to the beginning */
                if (~bfs_start) begin   
                    bfs_state <= BFS_LOAD;
                    bfs_done <= 1'b0;
                    bfs_sink <= 1'b0;   /* clear */
                    bfs_wr_en <= 1'b0;
                end
            end
            DELAY: begin
                bfs_state <= bfs_next_state;
                bfs_wr_en <= 1'b0;
            end
        endcase
    end
end

endmodule

/************************************************************************************************************
 *                                           Memory Controller                                              *
 ************************************************************************************************************/

module matrix_mem #(parameter WIDTH = 6)(
    input clk,
    input rstn,

    input [2:0] x,
    input [2:0] y,
    input wr_en,
    input data_in,

    input [1:0] init_select,
    input select_valid,

    output reg data_out
);

reg [WIDTH*WIDTH - 1:0] matrix;
wire [5:0] index;

assign index = x*WIDTH + y;

always @(posedge clk or negedge rstn) begin
    if (~rstn) begin
        matrix <= {(WIDTH*WIDTH-1){1'b0}};
        data_out <= 1'b0;
    end else begin 
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
        end else if (index < (WIDTH*WIDTH)) begin 
            if (wr_en)
                matrix[index] <= data_in;
            data_out = matrix[index];
        end
    end
end


endmodule