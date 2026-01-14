// File: playtime.sv
module Playtime (clk, reset, sprite_grid, spike_grid, score, hit);

    // Ports
    input  logic        clk, reset;                    // active-HIGH, synchronous
    input  logic [15:0][15:0] sprite_grid;             // row 0 = bottom, row 15 = top
    input  logic [15:0][15:0] spike_grid;              // MSB = leftmost column
    output logic [15:0]       score;                   // running score
    output logic              hit;                     // 1 if any overlap this cycle

    // State
    logic [3:0]  prev_row_ps, prev_row_ns;
    logic [15:0] score_ps,    score_ns;

    // Comb temps
    logic [3:0] cur_row;
    logic       row_found;
    logic       hit_any;

    // ---------------- Combinational: next-state + outputs ----------------
    always_comb begin
        // local loop index
        int r;

        // defaults
        prev_row_ns = prev_row_ps;
        score_ns    = score_ps;
        hit_any     = 1'b0;

        // decode current sprite row (first non-zero row; if none, hold)
        cur_row   = prev_row_ps;
        row_found = 1'b0;

        for (r = 0; r < 16; r = r + 1) begin
            // overlap detection per row
            if ( (sprite_grid[r] & spike_grid[r]) != 16'd0 ) hit_any = 1'b1;

            // find the sprite row once
            if (!row_found && (sprite_grid[r] != 16'd0)) begin
                cur_row   = r[3:0];
                row_found = 1'b1;
            end
        end

        // scoring: +1 only when moving UP (higher row index) and no hit
        if (row_found) begin
            if ((cur_row < prev_row_ps) && (hit_any == 1'b0)) begin
                score_ns = score_ps + 16'd1;
            end
            prev_row_ns = cur_row;  // track position only when a row is valid
        end

        // drive outputs (important!)
        hit   = hit_any;
        score = score_ps;
    end

    // ---------------- Sequential: registers ----------------
    always_ff @(posedge clk) begin
        // declare locals first (ModelSim-friendly)
        logic   [3:0] init_row;
        int           rr;

        if (reset) begin
            score_ps <= 16'd0;

            // seed prev_row to current sprite row to avoid a false +1 right after reset
            init_row = 4'd0;
            for (rr = 0; rr < 16; rr = rr + 1) begin
                if (sprite_grid[rr] != 16'd0) init_row = rr[3:0];
            end
            prev_row_ps <= init_row;
        end else begin
            score_ps    <= score_ns;
            prev_row_ps <= prev_row_ns;
        end
    end

endmodule


// ---------------- Testbench ----------------
module Playtime_testbench;

    // DUT I/O
    logic clk, reset;
    logic [15:0][15:0] sprite_grid;
    logic [15:0][15:0] spike_grid;
    logic [15:0]       score;
    logic              hit;

    // DUT
    Playtime dut (.*);

    // 100-unit clock
    parameter CLOCK_PERIOD = 100;
    initial clk = 1'b0;
    always  #(CLOCK_PERIOD/2) clk = ~clk;

    // monitor
    initial begin
        integer cur_row, ri;
        $display(" time | rst | cur_row | hit | score");
        forever begin
            @(posedge clk);
            cur_row = -1;
            for (ri = 0; ri < 16; ri = ri + 1) begin
                if (cur_row < 0 && (sprite_grid[ri] != 16'd0)) cur_row = ri;
            end
            $display("%5t |  %0d  |   %2d    |  %0d  | %0d",
                     $time, reset, cur_row, hit, score);
        end
    end

    // stimulus
    initial begin
        integer rr;
        int     COL;
        COL = 8;

        // init
        sprite_grid = '{default:16'd0};
        spike_grid  = '{default:16'd0};

        // reset and place sprite at row 0
        reset = 1'b1;
        sprite_grid[0] = 16'd0;
        sprite_grid[0][COL] = 1'b1;
        @(posedge clk); @(posedge clk);
        reset = 1'b0;

        // safe upward moves rows 1..4 (score +4)
        for (rr = 1; rr <= 4; rr = rr + 1) begin
            @(posedge clk);
            sprite_grid = '{default:16'd0};
            sprite_grid[rr][COL] = 1'b1;
            spike_grid  = '{default:16'd0};
        end
        @(posedge clk);

        // row 5 with overlap (no score inc)
        @(posedge clk);
        sprite_grid = '{default:16'd0};
        sprite_grid[5][COL] = 1'b1;
        spike_grid  = '{default:16'd0};
        spike_grid[5][COL]  = 1'b1;
        @(posedge clk);

        // row 6 safe (score +1)
        @(posedge clk);
        sprite_grid = '{default:16'd0};
        sprite_grid[6][COL] = 1'b1;
        spike_grid  = '{default:16'd0};
        @(posedge clk);

        // expect 5
        if (score !== 16'd5) begin
            $error("Expected score=5, got %0d", score);
        end

        repeat (4) @(posedge clk);
        $stop;
    end

endmodule