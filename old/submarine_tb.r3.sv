`timescale 1ns/1ps

module submarine_tb;

    reg clk;
    reg rstn;
    reg [1:0] init_select;
    reg select_valid;
    reg [2:0] x;
    reg [2:0] y;
    reg cord_valid;

    wire busy;
    wire hit;
    wire sink;
    wire done;

    localparam WIDTH = 6;

    submarine uut (
        .clk(clk),
        .rstn(rstn),
        .init_select(init_select),
        .select_valid(select_valid),
        .x(x),
        .y(y),
        .cord_valid(cord_valid),
        .busy(busy),
        .hit(hit),
        .sink(sink),
        .done(done)
    );

    // Track which coordinates have already been sent
    reg [WIDTH*WIDTH-1:0] sent_coords;

    integer idx;
    integer tries;

    initial begin
        $dumpfile("submarine_tb.vcd");
        $dumpvars(0, submarine_tb);

        clk = 0;
        rstn = 0;
        init_select = 0;
        select_valid = 0;
        x = 0;
        y = 0;
        cord_valid = 0;
        sent_coords = 0;

        #10 rstn = 1;

        // Select map
        #10 init_select = 2'b01;
        select_valid = 1;
        #10 select_valid = 0;

        // Wait a bit for init
        #20;

        tries = 0;
        while (!done && tries < 2000) begin
            @(negedge clk);
            if (!busy && !done) begin
                // Pick a random coordinate not already sent
                idx = $urandom_range(0, WIDTH*WIDTH-1);
                while (sent_coords[idx]) begin
                    idx = $urandom_range(0, WIDTH*WIDTH-1);
                end
                sent_coords[idx] = 1'b1;
                x = idx / WIDTH;
                y = idx % WIDTH;
                cord_valid = 1;
            end else begin
                cord_valid = 0;
            end
            tries = tries + 1;

            $display("tries: %d", tries);
        end

        // Wait for final signals to settle
        #20;
        $finish;
    end

    always #5 clk = ~clk;

endmodule