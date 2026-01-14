module Sprite (clk, reset, move_up, move_down, move_left, move_right, grid,hit);

    input  logic clk, reset,hit;
    input  logic move_up, move_down, move_left, move_right;
    output logic [15:0][15:0] grid;

    typedef enum logic [3:0] {
        POS_0,  POS_1,  POS_2,  POS_3,
        POS_4,  POS_5,  POS_6,  POS_7,
        POS_8,  POS_9,  POS_10, POS_11,
        POS_12, POS_13, POS_14, POS_15
    } state_t;

    state_t row_state, next_row_state;
    state_t col_state, next_col_state;

    logic [15:0] row_mask, col_mask;

    // FSM: Row movement logic
    always_comb begin
        next_row_state = row_state;
        if (move_up    && row_state != POS_15)   next_row_state = state_t'(row_state + 1);
        else if (move_down && row_state != POS_0) next_row_state = state_t'(row_state - 1);
    end

    // FSM: Column movement logic
    always_comb begin
        next_col_state = col_state;
        if (move_left  && col_state != POS_0)   next_col_state = state_t'(col_state - 1);
        else if (move_right && col_state != POS_15) next_col_state = state_t'(col_state + 1);
    end

    // Register state
    always_ff @(posedge clk) begin
        if (reset) begin
				row_state <= POS_0;
            col_state <= POS_7;
            
        end else if(!hit) begin
            row_state <= next_row_state;
            col_state <= next_col_state;
        end 
    end

    // row_mask based on present_row
    always_comb begin
        unique case (row_state)
            POS_0:  row_mask = 16'b1000_0000_0000_0000;
            POS_1:  row_mask = 16'b0100_0000_0000_0000;
            POS_2:  row_mask = 16'b0010_0000_0000_0000;
            POS_3:  row_mask = 16'b0001_0000_0000_0000;
            POS_4:  row_mask = 16'b0000_1000_0000_0000;
            POS_5:  row_mask = 16'b0000_0100_0000_0000;
            POS_6:  row_mask = 16'b0000_0010_0000_0000;
            POS_7:  row_mask = 16'b0000_0001_0000_0000;
            POS_8:  row_mask = 16'b0000_0000_1000_0000;
            POS_9:  row_mask = 16'b0000_0000_0100_0000;
            POS_10: row_mask = 16'b0000_0000_0010_0000;
            POS_11: row_mask = 16'b0000_0000_0001_0000;
            POS_12: row_mask = 16'b0000_0000_0000_1000;
            POS_13: row_mask = 16'b0000_0000_0000_0100;
            POS_14: row_mask = 16'b0000_0000_0000_0010;
            POS_15: row_mask = 16'b0000_0000_0000_0001;
            default: row_mask = 16'd0;
        endcase
    end

    // col_mask based on present_col
    always_comb begin
        case (col_state)
            POS_0:  col_mask = 16'b1000_0000_0000_0000;
            POS_1:  col_mask = 16'b0100_0000_0000_0000;
            POS_2:  col_mask = 16'b0010_0000_0000_0000;
            POS_3:  col_mask = 16'b0001_0000_0000_0000;
            POS_4:  col_mask = 16'b0000_1000_0000_0000;
            POS_5:  col_mask = 16'b0000_0100_0000_0000;
            POS_6:  col_mask = 16'b0000_0010_0000_0000;
            POS_7:  col_mask = 16'b0000_0001_0000_0000;
            POS_8:  col_mask = 16'b0000_0000_1000_0000;
            POS_9:  col_mask = 16'b0000_0000_0100_0000;
            POS_10: col_mask = 16'b0000_0000_0010_0000;
            POS_11: col_mask = 16'b0000_0000_0001_0000;
            POS_12: col_mask = 16'b0000_0000_0000_1000;
            POS_13: col_mask = 16'b0000_0000_0000_0100;
            POS_14: col_mask = 16'b0000_0000_0000_0010;
            POS_15: col_mask = 16'b0000_0000_0000_0001;
            default: col_mask = 16'd0;
        endcase
    end

    // grid update
    always_comb begin
        grid = '{default: 16'd0};
        for (int i = 0; i < 16; i++) begin
            if (row_mask[i]) grid[i] = col_mask;
        end
    end

endmodule

module Sprite_testbench();

    // DUT I/O
    logic clk, reset;
    logic move_up, move_down, move_left, move_right, hit;
    logic [15:0][15:0] grid;

    // DUT
    Sprite dut (
        .clk(clk),
        .reset(reset),
        .move_up(move_up),
        .move_down(move_down),
        .move_left(move_left),
        .move_right(move_right),
        .grid(grid),.hit(hit)
    );

    // 100-unit clock
    parameter CLOCK_PERIOD = 100;
    initial clk = 1'b0;
    always  #(CLOCK_PERIOD/2) clk = ~clk;

    // simple stimulus: just drive highs/lows on clock edges
    initial begin
        // init
        reset = 1'b1;
		  hit = 1'b0;
        move_up = 0; move_down = 0; move_left = 0; move_right = 0;
        @(posedge clk); @(posedge clk);
        reset = 1'b0;

		  
		  
        @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  
		  
        @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  
        @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  
        // down pulse (1 cycle)
        @(posedge clk); move_down = 1;
        @(posedge clk); move_down = 0;

        // right pulse (1 cycle)
        @(posedge clk); move_right = 1;
        @(posedge clk); move_right = 0;

        // two more downs
        @(posedge clk); move_down = 1;
        @(posedge clk); move_down = 0;
        @(posedge clk); move_down = 1;
        @(posedge clk); move_down = 0;

        // left then up
        @(posedge clk); move_left = 1;
        @(posedge clk); move_left = 0;

        @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  
		   // down pulse (1 cycle)
        @(posedge clk); move_down = 1;
        @(posedge clk); move_down = 0;

		   // down pulse (1 cycle)
        @(posedge clk); move_down = 1;
        @(posedge clk); move_down = 0;

		   // down pulse (1 cycle)
        @(posedge clk); move_down = 1;
        @(posedge clk); move_down = 0;
		  
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;@(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
		  
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;
		  @(posedge clk); move_up = 1;
        @(posedge clk); move_up = 0;


        // sit for a few cycles
        repeat (2) @(posedge clk);

        $stop;
    end

endmodule