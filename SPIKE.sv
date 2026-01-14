// ===================== SPIKE.sv =====================
module SPIKE (clk, reset, grid, hit);

    // Ports (row 0 = bottom; MSB = left)
    input  logic        clk, reset, hit;              // hit=1 -> freeze cars
    output logic [15:0][15:0] grid;

    // Params
    localparam int NROWS    = 16;
    localparam int MAX_OBJS = 4;

    // Per-row state (registered + next)
    logic [15:0] lane_mask_ps [NROWS], lane_mask_ns [NROWS]; // car bitmap
    logic        dir_left_ps  [NROWS], dir_left_ns  [NROWS]; // 1=left, 0=right
    logic [1:0]  speed_sel_ps [NROWS], speed_sel_ns [NROWS]; // 0..3
    logic [7:0]  cnt_ps       [NROWS], cnt_ns       [NROWS]; // move countdown

    // 16-bit LFSR (x^16 + x^14 + x^13 + x^11 + 1)
    logic [15:0] lfsr_ps, lfsr_ns;
    logic        lfsr_fb;

    // ---------------- Combinational: next-state + outputs ----------------
    always_comb begin
        // locals first (tool-friendly)
        int r;

        // LFSR next
        lfsr_fb = lfsr_ps[15] ^ lfsr_ps[13] ^ lfsr_ps[12] ^ lfsr_ps[10];
        lfsr_ns = {lfsr_ps[14:0], lfsr_fb};

        // default: hold current state
        for (r = 0; r < NROWS; r = r + 1) begin
            lane_mask_ns[r] = lane_mask_ps[r];
            dir_left_ns [r] = dir_left_ps [r];
            speed_sel_ns[r] = speed_sel_ps[r];
            cnt_ns      [r] = cnt_ps      [r];
        end

        // OUTPUT comes from REGISTERED state (so freeze truly freezes display)
        for (r = 0; r < NROWS; r = r + 1) begin
            grid[r] = lane_mask_ps[r];
        end

        // Update rows only when NOT hit
        if (!hit) begin
            for (r = 0; r < NROWS; r = r + 1) begin
                // keep rows 0,1,15 empty + still
                if (r == 0 || r == 1 || r == 15) begin
                    lane_mask_ns[r] = 16'd0;
                    cnt_ns[r]       = 8'd0;
                end else begin
                    if (cnt_ps[r] == 8'd0) begin
                        // shift/rotate one step (wrap)
                        if (dir_left_ps[r])
                            lane_mask_ns[r] = {lane_mask_ps[r][14:0], lane_mask_ps[r][15]};   // left
                        else
                            lane_mask_ns[r] = {lane_mask_ps[r][0],    lane_mask_ps[r][15:1]}; // right
                        // reload countdown from speed
                        unique case (speed_sel_ps[r])
                            2'd0: cnt_ns[r] = 8'd1;
                            2'd1: cnt_ns[r] = 8'd2;
                            2'd2: cnt_ns[r] = 8'd4;
                            default: cnt_ns[r] = 8'd8;
                        endcase
                    end else begin
                        cnt_ns[r] = cnt_ps[r] - 8'd1;
                    end
                end
            end
        end
    end

    // ---------------- Sequential: registers / reset seeding ----------------
    always_ff @(posedge clk) begin
        // locals first
        int r, k, c;
        logic [15:0] rnd, acc, car;
        logic        fb_bit;
        int          nobjs;
        logic [3:0]  col;
        logic [1:0]  len_sel, sel;

        if (reset) begin
            // seed LFSR and rows
            lfsr_ps <= 16'h1ACE;
            rnd     = 16'hC0DE;

            for (r = 0; r < NROWS; r = r + 1) begin
                // decorrelate rnd a little
                fb_bit = rnd[15]^rnd[13]^rnd[12]^rnd[10]; rnd = {rnd[14:0], fb_bit};
                fb_bit = rnd[15]^rnd[13]^rnd[12]^rnd[10]; rnd = {rnd[14:0], fb_bit};

                if (r == 0 || r == 1 || r == 15) begin
                    // reserved rows: empty + stopped
                    lane_mask_ps[r] <= 16'd0;
                    dir_left_ps [r] <= 1'b1;
                    speed_sel_ps[r] <= 2'd0;
                    cnt_ps      [r] <= 8'd0;
                end else begin
                    // direction
                    dir_left_ps[r] <= rnd[0];

                    // speed select (bits [3:2])
                    sel = {rnd[3], rnd[2]};
                    speed_sel_ps[r] <= sel;

                    // #cars 0..4
                    nobjs = {rnd[6], rnd[5], rnd[4]};
                    if (nobjs > MAX_OBJS) nobjs = MAX_OBJS;

                    // build lane bitmap into temp 'acc'
                    acc = 16'd0;
                    for (k = 0; k < MAX_OBJS; k = k + 1) begin
                        // advance rnd per potential car
                        fb_bit = rnd[15]^rnd[13]^rnd[12]^rnd[10]; rnd = {rnd[14:0], fb_bit};

                        if (k < nobjs) begin
                            col = rnd[7:4]; // 0..15 (0 = left/MSB)

                            // length 1/2/3 from bits [9:8]
                            if (rnd[9])      len_sel = 2'd2; // 3 cells
                            else if (rnd[8]) len_sel = 2'd1; // 2 cells
                            else             len_sel = 2'd0; // 1 cell

                            // base mask at left edge
                            unique case (len_sel)
                                2'd0: car = 16'b1000_0000_0000_0000;    // len=1
                                2'd1: car = 16'b1100_0000_0000_0000;    // len=2
                                default: car = 16'b1110_0000_0000_0000; // len=3
                            endcase

                            // rotate-right by 'col' to position
                            for (c = 0; c < 16; c = c + 1)
                                if (c < col) car = {car[0], car[15:1]};

                            acc = acc | car;
                        end
                    end

                    // commit bitmap + initial countdown
                    lane_mask_ps[r] <= acc;
                    unique case (sel)
                        2'd0: cnt_ps[r] <= 8'd1;
                        2'd1: cnt_ps[r] <= 8'd2;
                        2'd2: cnt_ps[r] <= 8'd4;
                        default: cnt_ps[r] <= 8'd8;
                    endcase
                end
            end

        end else if (!hit) begin
            // normal updates when not hit (frozen otherwise)
            lfsr_ps <= lfsr_ns;
            for (r = 0; r < NROWS; r = r + 1) begin
                lane_mask_ps[r] <= lane_mask_ns[r];
                dir_left_ps [r] <= dir_left_ns [r];
                speed_sel_ps[r] <= speed_sel_ns[r];
                cnt_ps      [r] <= cnt_ns      [r];
            end
        end
        // else: hit==1 -> hold registered state
    end

endmodule





module SPIKE_testbench();

    // DUT I/O
    logic clk, reset, hit;
    logic [15:0][15:0] grid;

    // DUT
    SPIKE dut (
        .clk(clk),
        .reset(reset),
        .grid(grid),.hit(hit));

    // 100-unit clock
    parameter CLOCK_PERIOD = 100;
    initial clk = 1'b0;
    always  #(CLOCK_PERIOD/2) clk = ~clk;

    // simple stimulus: just drive highs/lows on clock edges
    initial begin
        // init
        reset = 1'b1;
		  hit = 1'b0;
        
        @(posedge clk); @(posedge clk);
        reset = 1'b0;


        // sit for a few cycles
        repeat (50) @(posedge clk);
		  hit = 1'b0;
		  repeat (5) @(posedge clk);

        $stop;
    end

endmodule