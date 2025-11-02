`timescale 1ns/1ps

module submarine_tb;

    reg clk;
    reg rstn;
    reg [1:0] init_select;
    reg [2:0] x;
    reg [2:0] y;
    reg cord_valid;

    wire busy;
    wire hit;
    wire sink;
    wire done;

    localparam WIDTH = 6;
    localparam MAX_GAMES = 10;
    localparam MAX_CLOCK_CYCLES = 1000;

    submarine_top uut (
        .clk(clk),
        .rstn(rstn),
        .init_select(init_select),
        .x(x),
        .y(y),
        .cord_valid(cord_valid),
        .busy(busy),
        .hit(hit),
        .sink(sink),
        .done(done)
    );

    // Game statistics
    integer game_num;
    integer clock_count;
    integer total_clock_cycles;
    integer successful_games;
    integer failed_games;
    
    // Per-game tracking
    reg [WIDTH*WIDTH-1:0] sent_coords;
    reg game_failed;
    integer idx;

    initial begin
        $dumpfile("submarine_tb.vcd");
        $dumpvars(0, submarine_tb);

        // Initialize
        clk = 0;
        rstn = 0;
        init_select = 2'b01;  // Use map 1
        x = 0;
        y = 0;
        cord_valid = 0;
        
        // Global statistics
        total_clock_cycles = 0;
        successful_games = 0;
        failed_games = 0;

        $display("=== Starting 10 Submarine Games ===");

        // Run 10 games
        for (game_num = 1; game_num <= MAX_GAMES; game_num = game_num + 1) begin
            $display("\n--- Game %0d ---", game_num);
            
            // Reset game-specific variables
            sent_coords = 0;
            clock_count = 0;
            game_failed = 0;
            
            // Assert reset
            rstn = 0;
            #20;
            rstn = 1;
            #20;

            // Play the game
            while (!done && !game_failed && clock_count < MAX_CLOCK_CYCLES) begin
                @(negedge clk);
                clock_count = clock_count + 1;
                
                if (!busy && !done) begin
                    // Check if all coordinates have been tested
                    if (&sent_coords) begin
                        $display("ERROR: Game %0d - All %0d coordinates tested but game not done!", game_num, WIDTH*WIDTH);
                        failed_games = failed_games + 1;
                        game_failed = 1;
                    end else begin
                        // Pick a random coordinate not already sent
                        idx = $urandom_range(0, WIDTH*WIDTH-1);
                        while (sent_coords[idx]) begin
                            idx = $urandom_range(0, WIDTH*WIDTH-1);
                        end
                        sent_coords[idx] = 1'b1;
                        x = idx / WIDTH;
                        y = idx % WIDTH;
                        cord_valid = 1;
                    end
                end else begin
                    cord_valid = 0;
                end
            end

            // Game finished - check results
            if (done) begin
                $display("SUCCESS: Game %0d completed in %0d clock cycles", game_num, clock_count);
                successful_games = successful_games + 1;
            end else if (!game_failed) begin
                $display("TIMEOUT: Game %0d did not complete within %0d clock cycles", game_num, MAX_CLOCK_CYCLES);
                failed_games = failed_games + 1;
            end
            
            total_clock_cycles = total_clock_cycles + clock_count;
            
            // Wait 10 clock cycles before next game (except for last game)
            if (game_num < MAX_GAMES) begin
                cord_valid = 0;
                repeat(10) @(posedge clk);
            end
        end

        // Final statistics
        $display("\n=== Final Statistics ===");
        $display("Total Games: %0d", MAX_GAMES);
        $display("Successful Games: %0d", successful_games);
        $display("Failed Games: %0d", failed_games);
        $display("Total Clock Cycles: %0d", total_clock_cycles);
        if (successful_games > 0) begin
            $display("Average Clock Cycles per Successful Game: %0d", total_clock_cycles / successful_games);
        end
        $display("Success Rate: %0d%%", (successful_games * 100) / MAX_GAMES);

        $finish;
    end

    always #5 clk = ~clk;

endmodule
