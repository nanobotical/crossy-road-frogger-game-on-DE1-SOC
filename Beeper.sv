

module Beeper (clk, reset, speaker,hit);
   input  logic clk, reset, hit;
	output logic speaker;

    // 56,818 cycles per half-period at 50 MHz
    reg [15:0] counter;
	 always @(posedge clk) if(counter==56817) counter <= 0; else counter <= counter+1;

    assign speaker = (counter[15] & hit);
	 

endmodule
