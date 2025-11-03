/*
 * BFS (Breadth-First Search) Module
 * Used for submarine sink detection with external memory interface
 * Split into Main FSM and Neighbor-Check FSM
 */

module bfs #(parameter WIDTH = 6) (
    input clk,
    input rstn,

    input [2:0] x,
    input [2:0] y,

    // External memory interface
    output reg [2:0] mem_addr_x,
    output reg [2:0] mem_addr_y,
    output reg mem_wr_en,
    output reg [1:0] mem_wr_data,
    output reg mem_in_valid,
    input [1:0] mem_rd_data,
    input mem_ready,

    input bfs_start,

    output reg bfs_sink,
    output reg bfs_done
);

reg [2:0] orig_x;
reg [2:0] orig_y;

wire [2:0] x_right;
wire [2:0] x_left;
wire [2:0] y_upper;
wire [2:0] y_lower;
assign x_right = (orig_x == WIDTH-1) ?  WIDTH-1 : orig_x + 1;
assign x_left = (orig_x == 0) ?         0 : orig_x - 1;
assign y_upper = (orig_y == WIDTH-1) ?  WIDTH-1 : orig_y + 1;
assign y_lower = (orig_y == 0) ?        0 : orig_y - 1; 

// Main FSM states
reg [3:0] bfs_state;
reg [3:0] bfs_next_state;
localparam BFS_LOAD = 4'b0000;
localparam BFS_CHECK = 4'b0010;
localparam BFS_CLEAR = 4'b1000;
localparam BFS_DONE = 4'b1110;
localparam DELAY = 4'b1111;

// Neighbor Check FSM states
reg [2:0] check_state;
reg [2:0] check_next_state;
localparam CHECK_IDLE = 3'b000;
localparam X_L = 3'b001;
localparam X_R = 3'b010;
localparam Y_U = 3'b011;
localparam Y_D = 3'b100;
localparam CHECK_FOUND = 3'b101;
localparam CHECK_DELAY = 3'b110;

// State name debugging
reg [8*8-1:0] bfs_state_name;
always @(bfs_state) begin
    case (bfs_state) 
        BFS_LOAD : bfs_state_name <= "LOAD";
        BFS_CHECK : bfs_state_name <= "CHECK";
        BFS_CLEAR : bfs_state_name <= "CLEAR";
        BFS_DONE : bfs_state_name <= "DONE";
        DELAY : bfs_state_name <= "DELAY";
        default: bfs_state_name <= "UNKNOWN";
    endcase
end

reg [8*8-1:0] check_state_name;
always @(check_state) begin
    case (check_state) 
        CHECK_IDLE : check_state_name <= "IDLE";
        X_L : check_state_name <= "X_L";
        X_R : check_state_name <= "X_R";
        Y_U : check_state_name <= "Y_U";
        Y_D : check_state_name <= "Y_D";
        CHECK_FOUND : check_state_name <= "C_FOUND";
        CHECK_DELAY : check_state_name <= "C_DELAY";
        default: check_state_name <= "UNKNOWN";
    endcase
end

// Inter-FSM communication
reg check_start;
reg check_done_sig;

// Neighbor detection variables
reg found_gray;
reg found_white;
wire found;
assign found = found_gray | found_white;

reg [2:0] gray_x;
reg [2:0] gray_y;
reg [2:0] cell_count;  // Changed from 2 bits to 3 bits to handle up to 4 neighbors

// Main BFS FSM
always @(posedge clk or negedge rstn) begin 
    if (~rstn) begin 
        bfs_sink <= 1'b0;
        bfs_done <= 1'b0;
        bfs_state <= BFS_LOAD;
        bfs_next_state <= BFS_LOAD;
        check_start <= 1'b0;
        orig_x <= 3'b000;
        orig_y <= 3'b000;
        found_gray <= 1'b0;
        found_white <= 1'b0;
        cell_count <= 3'b000;
        gray_x <= 3'b000;
        gray_y <= 3'b000;
        mem_addr_x <= 3'b0;
        mem_addr_y <= 3'b0;
        mem_wr_en <= 1'b0;
        mem_wr_data <= 2'b00;
        mem_in_valid <= 1'b0;
    end else begin
        case (bfs_state)
            BFS_LOAD : begin
                if (bfs_start) begin
                    orig_x <= x;
                    orig_y <= y;
                    bfs_state <= BFS_CHECK;
                    found_gray <= 1'b0;
                    found_white <= 1'b0;
                    cell_count <= 0;
                end
            end
            
            BFS_CHECK : begin
                check_start <= 1'b1;  // Start neighbor check FSM
                if (check_done_sig) begin
                    check_start <= 1'b0;
                    
                    // Handle memory writing based on neighbor check results
                    if (cell_count > 1) begin
                        mem_addr_x <= orig_x;
                        mem_addr_y <= orig_y;
                        mem_wr_en <= 1'b1;
                        mem_wr_data <= 2'b10;  // Gray
                        mem_in_valid <= 1'b1;
                        bfs_sink <= 1'b0;
                        bfs_state <= DELAY;
                        bfs_next_state <= BFS_DONE;
                    end else if (cell_count == 0) begin 
                        mem_addr_x <= orig_x;
                        mem_addr_y <= orig_y;
                        mem_wr_en <= 1'b1;
                        mem_wr_data <= 2'b00;  // Clear the original bit
                        mem_in_valid <= 1'b1;
                        bfs_sink <= 1'b1;  // Sink - no neighbors found
                        bfs_state <= DELAY;
                        bfs_next_state <= BFS_DONE;
                    /* at this point, we found 1 cell */
                    end else if (found_white) begin
                        mem_addr_x <= orig_x;
                        mem_addr_y <= orig_y;
                        mem_wr_en <= 1'b1;
                        mem_wr_data <= 2'b10;  // Gray
                        mem_in_valid <= 1'b1;
                        bfs_sink <= 1'b0;
                        bfs_state <= DELAY;
                        bfs_next_state <= BFS_DONE;
                    end else if (found_gray) begin
                        bfs_sink <= 1'b0;
                        mem_addr_x <= orig_x;
                        mem_addr_y <= orig_y;
                        mem_wr_en <= 1'b1;
                        mem_wr_data <= 2'b00;  // Clear the original bit
                        mem_in_valid <= 1'b1;
                        bfs_state <= DELAY;
                        bfs_state <= BFS_CLEAR;
                    end
                end
            end
            
            BFS_CLEAR : begin
                orig_x <= gray_x;
                orig_y <= gray_y;
                found_gray <= 1'b0;
                found_white <= 1'b0;
                cell_count <= 3'b000;
                bfs_state <= BFS_CHECK;
            end
            
            BFS_DONE : begin
                bfs_done <= 1'b1;
                mem_wr_en <= 1'b0;
                if (~bfs_start) begin   
                    bfs_state <= BFS_LOAD;
                    bfs_done <= 1'b0;
                    bfs_sink <= 1'b0;
                end
            end
            
            DELAY: begin
                mem_in_valid <= 1'b0;  // Clear valid signal
                mem_wr_en <= 1'b0;
                if (mem_ready) begin
                    bfs_state <= bfs_next_state;
                end
            end
        endcase
    end
end

// Neighbor Check FSM
always @(posedge clk or negedge rstn) begin 
    if (~rstn) begin 
        check_state <= CHECK_IDLE;
        check_next_state <= CHECK_IDLE;
        check_done_sig <= 1'b0;
    end else begin
        case (check_state)
            CHECK_IDLE : begin
                if (check_start) begin
                    found_gray <= 1'b0;
                    found_white <= 1'b0;
                    cell_count <= 3'b000;
                    check_done_sig <= 1'b0;
                    mem_addr_x <= x_left;
                    mem_addr_y <= orig_y;
                    mem_wr_en <= 1'b0;
                    mem_in_valid <= 1'b1;
                    check_state <= CHECK_DELAY;
                    check_next_state <= X_L;
                end
            end
            
            X_L : begin
                // Only count if this is a valid neighbor (not same as current position)
                if (x_left != orig_x) begin
                    found_gray <= found_gray | mem_rd_data[1];
                    found_white <= found_white | mem_rd_data[0];
                    
                    if (mem_rd_data[1] | mem_rd_data[0]) begin
                        cell_count <= cell_count + 1;
                    end

                    if (mem_rd_data[1]) begin
                        gray_x <= mem_addr_x;
                        gray_y <= mem_addr_y;
                    end 
                end

                mem_addr_x <= x_right;
                mem_addr_y <= orig_y;
                mem_wr_en <= 1'b0;
                mem_in_valid <= 1'b1;
                check_state <= CHECK_DELAY;
                check_next_state <= X_R;
            end
            
            X_R : begin
                // Only count if this is a valid neighbor (not same as current position)
                if (x_right != orig_x) begin
                    found_gray <= found_gray | mem_rd_data[1];
                    found_white <= found_white | mem_rd_data[0];
                    
                    if (mem_rd_data[1] | mem_rd_data[0]) begin
                        cell_count <= cell_count + 1;
                    end

                    if (mem_rd_data[1]) begin
                        gray_x <= mem_addr_x;
                        gray_y <= mem_addr_y;
                    end 
                end 
                
                mem_addr_x <= orig_x;
                mem_addr_y <= y_upper;
                mem_wr_en <= 1'b0;
                mem_in_valid <= 1'b1;
                check_state <= CHECK_DELAY;
                check_next_state <= Y_U;
            end
            
            Y_U : begin
                // Only count if this is a valid neighbor (not same as current position)
                if (y_upper != orig_y) begin
                    found_gray <= found_gray | mem_rd_data[1];
                    found_white <= found_white | mem_rd_data[0];
                    
                    if (mem_rd_data[1] | mem_rd_data[0]) begin
                        cell_count <= cell_count + 1;
                    end

                    if (mem_rd_data[1]) begin
                        gray_x <= mem_addr_x;
                        gray_y <= mem_addr_y;
                    end 
                end
                
                mem_addr_x <= orig_x;
                mem_addr_y <= y_lower;
                mem_wr_en <= 1'b0;
                mem_in_valid <= 1'b1;
                check_state <= CHECK_DELAY;
                check_next_state <= Y_D;
            end
            
            Y_D : begin
                // Only count if this is a valid neighbor (not same as current position)
                if (y_lower != orig_y) begin
                    found_gray <= found_gray | mem_rd_data[1];
                    found_white <= found_white | mem_rd_data[0];
                    
                    if (mem_rd_data[1] | mem_rd_data[0]) begin
                        cell_count <= cell_count + 1;
                    end

                    if (mem_rd_data[1]) begin
                        gray_x <= mem_addr_x;
                        gray_y <= mem_addr_y;
                    end 
                end 
                
                check_state <= CHECK_FOUND;
            end
            
            CHECK_FOUND : begin
                // Only signal completion - no memory writing
                check_done_sig <= 1'b1;
                if (check_start == 1'b0) begin
                    check_state <= CHECK_IDLE;
                    check_done_sig <= 1'b0;
                end
            end
            
            CHECK_DELAY: begin
                mem_in_valid <= 1'b0;  // Clear valid signal
                mem_wr_en <= 1'b0;
                if (mem_ready) begin
                    check_state <= check_next_state;
                end
            end
        endcase
    end
end

endmodule
