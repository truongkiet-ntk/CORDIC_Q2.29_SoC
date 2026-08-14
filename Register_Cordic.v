module Register_Cordic (
    input wire clk,
    input wire rst,
    input wire signed [31:0] data_in1,
    input wire signed [31:0] data_in2,
    input wire signed [31:0] data_in3,
    input wire mode_in,
	 input wire valid_bit_in,
    output reg signed [31:0] data_out1,
    output reg signed [31:0] data_out2,
    output reg signed [31:0] data_out3,
    output reg mode_out,
	 output reg valid_bit_out
);

	always @(posedge clk or posedge rst) begin
		if (rst) begin
			data_out1 <= 32'd0;
			data_out2 <= 32'd0;
			data_out3 <= 32'd0;
			mode_out <= 1'b0;
			valid_bit_out <= 1'b0;
		end else begin
			data_out1 <= data_in1;
			data_out2 <= data_in2;
			data_out3 <= data_in3;
			mode_out <= mode_in;
			valid_bit_out <= valid_bit_in;
		end
	end
endmodule 