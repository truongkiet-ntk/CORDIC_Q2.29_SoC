module red_leds
(
	input iClk,
	input iReset_n,
	input iChip_select_n,
	input iWrite_n,
	input [31:0] iRed_leds_data,
	output reg [31:0] oRed_leds
);
	always@(posedge iClk, negedge iReset_n)
	begin
		if(~iReset_n)
		begin
			oRed_leds <= 32'd0;
		end
		else
		begin
			if(~iChip_select_n & ~iWrite_n)
			begin
				oRed_leds <= iRed_leds_data;
			end
		end
	end
endmodule 