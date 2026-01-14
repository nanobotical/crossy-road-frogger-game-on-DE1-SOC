// ===================== DE1_SoC.sv (no PlayTop) =====================
// Top that drives the 16x16 LED board (via LEDDriver), runs Sprite/SPIKE/Playtime,
// syncs buttons (2-FF + one-shot), and beeps (melody + die SFX).
// Ports use non-ANSI header + declarations inside (your style).

module DE1_SoC (
    HEX0, HEX1, HEX2, HEX3, HEX4, HEX5,
    KEY, SW, LEDR, GPIO_0, GPIO_1, CLOCK_50
);
    // -------- Port declarations --------
    output logic [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    output logic [9:0]  LEDR;
    output logic [35:0] GPIO_0;     // buzzer on GPIO_0[0]
    output logic [35:0] GPIO_1;     // LED matrix driver
    input  logic [3:0]  KEY;        // active-LOW: [3]=UP [2]=DOWN [1]=LEFT [0]=RIGHT
    input  logic [9:0]  SW;         // SW[9]=reset
    input  logic        CLOCK_50;

    // -------- Clocks (use YOUR divider) --------
    logic [31:0] div;
    // Your module signature: clock_divider (clock, reset, divided_clocks)
    // You can tie reset to 1'b0 (since your divider ignores it), or to 'reset' for future-proofing.
    clock_divider u_div (.clock(CLOCK_50), .reset(1'b0), .divided_clocks(div));

    // ~1.5 kHz scan clock for LED matrix (matches sample)
    localparam int SCAN_BIT = 14;   // 50e6 / 2^(14+1) ≈ 1526 Hz row rate
    logic SYS_CLK;  assign SYS_CLK = div[SCAN_BIT];

    // Game tick (tune speed). Lower bit => faster. For sim you can use CLOCK_50.
    localparam int GAME_BIT = 22;   // ~3 Hz
    logic clkGame; assign clkGame = div[GAME_BIT];
    // assign clkGame = CLOCK_50;    // <-- uncomment for simulation speed

    // -------- Reset --------
    // Use SW[9] (active-HIGH) OR KEY0 press (active-LOW) as reset
    logic reset;
    assign reset = SW[9] ;

    // -------- Button sync (2-FF) + one-shot pulses --------
    logic up_sync, down_sync, left_sync, right_sync;
    sync2 u_sync_up    (.clk(clkGame), .reset(reset), .din(~KEY[3]), .dout(up_sync));
    sync2 u_sync_down  (.clk(clkGame), .reset(reset), .din(~KEY[2]), .dout(down_sync));
    sync2 u_sync_left  (.clk(clkGame), .reset(reset), .din(~KEY[1]), .dout(left_sync));
    sync2 u_sync_right (.clk(clkGame), .reset(reset), .din(~KEY[0]), .dout(right_sync));

    logic move_up, move_down, move_left, move_right;
    edge_pulse u_p_up    (.clk(clkGame), .reset(reset), .in(up_sync),    .pulse(move_up));
    edge_pulse u_p_down  (.clk(clkGame), .reset(reset), .in(down_sync),  .pulse(move_down));
    edge_pulse u_p_left  (.clk(clkGame), .reset(reset), .in(left_sync),  .pulse(move_left));
    edge_pulse u_p_right (.clk(clkGame), .reset(reset), .in(right_sync), .pulse(move_right));

    // -------- Game cores --------
    logic [15:0][15:0] sprite_grid, spike_grid;
    logic [15:0]       score;
    logic              hit;

    Sprite u_sprite (
        .clk(clkGame), .reset(reset),
        .move_up(move_up), .move_down(move_down),
        .move_left(move_left), .move_right(move_right),
        .grid(sprite_grid),.hit(hit)
    );

    SPIKE u_spike (
        .clk(clkGame), .reset(reset),
        .grid(spike_grid),.hit(hit)
    );

    Playtime u_play (
        .clk(clkGame), .reset(reset),
        .sprite_grid(sprite_grid), .spike_grid(spike_grid),
        .score(score), .hit(hit)
    );

    // -------- Beeper: melody + die SFX (hit rising edge) --------
    logic audio_out;
    
    Beeper u_beep (
        .clk(CLOCK_50), .reset(reset),
        .speaker(audio_out),.hit(hit)
    );

    // -------- LED matrix: green = sprite, red = spikes --------
    logic [15:0][15:0] RedPixels, GrnPixels;
    assign RedPixels = spike_grid;     // cars (red)
    assign GrnPixels = sprite_grid;    // player (green)

    // Provided LED driver (do not modify)
    LEDDriver Driver (
        .CLK(SYS_CLK), .RST(reset), .EnableCount(1'b1),
        .RedPixels(RedPixels), .GrnPixels(GrnPixels),
        .GPIO_1(GPIO_1)
    );
	 
	 

    // -------- 7-seg: show score ONLY on HEX1/HEX0 (active-LOW) --------
    always_comb begin
        HEX1 = to7seg_hex(score[7:4]);
        HEX0 = to7seg_hex(score[3:0]);
        
    end
	 
	 hit_display u_disp (
    .clk(CLOCK_50),
    .hit(hit),
    .hex2(HEX2), .hex3(HEX3), .hex4(HEX4), .hex5(HEX5));

    // -------- LEDs + Buzzer pin --------
    always_comb begin
        LEDR       = '0;
        LEDR[9]    = hit;           // hit indicator
        LEDR[0]    = audio_out;     // handy to scope

                    // route buzzer to GPIO_0[0]
        GPIO_0[0]  = audio_out ;
    end

    // ---- 7-seg hex encoder (active-LOW) ----
    function logic [6:0] to7seg_hex (input logic [3:0] d);
        case (d)   //        abc_defg (0=ON)
            4'h0: to7seg_hex = 7'b100_0000;
            4'h1: to7seg_hex = 7'b111_1001;
            4'h2: to7seg_hex = 7'b010_0100;
            4'h3: to7seg_hex = 7'b011_0000;
            4'h4: to7seg_hex = 7'b001_1001;
            4'h5: to7seg_hex = 7'b001_0010;
            4'h6: to7seg_hex = 7'b000_0010;
            4'h7: to7seg_hex = 7'b111_1000;
            4'h8: to7seg_hex = 7'b000_0000;
            4'h9: to7seg_hex = 7'b001_0000;
            4'hA: to7seg_hex = 7'b000_1000;
            4'hB: to7seg_hex = 7'b000_0011;
            4'hC: to7seg_hex = 7'b100_0110;
            4'hD: to7seg_hex = 7'b010_0001;
            4'hE: to7seg_hex = 7'b000_0110;
            default: to7seg_hex = 7'b000_1110; // F
        endcase
    endfunction
endmodule

// ================= helpers =================

// 2-FF synchronizer (debounce-ish + metastability guard)
module sync2 (clk, reset, din, dout);
    input  logic clk, reset, din;
    output logic dout;
    logic s0, s1;
    always_ff @(posedge clk) begin
        if (reset) begin s0 <= 1'b0; s1 <= 1'b0; end
        else begin          s0 <= din; s1 <= s0; end
    end
    assign dout = s1;
endmodule

// rising-edge one-shot
module edge_pulse (clk, reset, in, pulse);
    input  logic clk, reset, in;
    output logic pulse;
    logic in_d;
    always_ff @(posedge clk) begin
        if (reset) in_d <= 1'b0;
        else       in_d <= in;
    end
    always_comb begin
        pulse = (in & ~in_d);
    end
endmodule


// ===================== DE1_SoC_testbench.sv =====================
module DE1_SoC_testbench();

    // DUT I/O (match your DE1_SoC ports)
    logic CLOCK_50;
    logic [3:0]  KEY;
    logic [9:0]  SW;
    wire  [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    wire  [9:0]  LEDR;
    wire  [35:0] GPIO_0, GPIO_1;

    // Instantiate DUT
    DE1_SoC dut (.*);

    // -------- 50 MHz base clock (for sim you can pick any fast period) --------
    parameter CLOCK_PERIOD = 20; // 50 MHz -> 20 time units
    initial CLOCK_50 = 1'b0;
    always  #(CLOCK_PERIOD/2) CLOCK_50 = ~CLOCK_50;

    // -------- helpers that wait on the DUT's game clock --------
    task automatic wait_game(input int n);
        int i;
        begin
            for (i = 0; i < n; i = i + 1) @(posedge dut.clkGame);
        end
    endtask

    task automatic soft_reset();
        begin
            // SW[9] is active-HIGH reset in your top
            SW[9] = 1'b1;  wait_game(3);
            SW[9] = 1'b0;  wait_game(2);
        end
    endtask

    // KEY[3] = UP (active-LOW). Hold a few clkGame cycles for the 2-FF sync + edge pulser.
    task automatic press_up(input int hold_cycles);
        begin
            KEY[3] = 1'b0;         // press (active-low)
            wait_game(hold_cycles);
            KEY[3] = 1'b1;         // release
            wait_game(1);
        end
    endtask

    // -------- monitor: print each game tick --------
    initial begin
        int r, cur_row;
        $display(" time | tick |  UP | score | hit | row ");
        forever begin
            @(posedge dut.clkGame);
            cur_row = -1;
            // sprite_grid is internal to DUT; okay to peek via hierarchy
            for (r = 0; r < 16; r++) begin
                if (cur_row < 0 && (dut.sprite_grid[r] != 16'd0)) cur_row = r;
            end
            $display("%7t |  *   |  %0d | %5d |  %0d | %2d",
                     $time, (KEY[3]==1'b0), dut.score, dut.hit, cur_row);
        end
    end

    // -------- stimulus --------
    initial begin
        // defaults
        KEY = 4'b1111;     // all released (active-LOW)
        SW  = 10'd0;

        // TIP: for fast sim, temporarily set 'clkGame = CLOCK_50;' inside DE1_SoC.sv.

        // let divider settle a bit
        wait_game(2);

        // reset field
        soft_reset();

        // go UP 15 times
        repeat (15) press_up(3);
        wait_game(4);

        // reset
        soft_reset();

        // go UP 4 times
        repeat (4) press_up(3);
        wait_game(6);

        $stop;
    end

endmodule