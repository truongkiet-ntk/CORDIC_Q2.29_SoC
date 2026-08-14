module Execute_Cordic(
    input wire signed [31:0] x_in,
    input wire signed [31:0] y_in,
    input wire signed [31:0] z_in,
    input wire signed [31:0] const_atan,
    input wire signed [31:0] x_shift_in,
    input wire signed [31:0] y_shift_in,
    input wire mode,
    output wire signed [31:0] x_out,
    output wire signed [31:0] y_out,
    output wire signed [31:0] z_out
);

	 reg signed [32:0] x_reg, y_reg, z_reg;
	 always @* begin
			if (mode == 1'b0) begin 
			// rotation
				if (z_in[31] == 1'b0) begin
					x_reg = x_in - y_shift_in;
					y_reg = y_in + x_shift_in;
					z_reg = z_in - const_atan;
				end else begin
					x_reg = x_in + y_shift_in;
					y_reg = y_in - x_shift_in;
					z_reg = z_in + const_atan;
				end
			end 
			else begin
			// vectoring
				if (y_in[31] == 1'b0) begin
					x_reg = x_in + y_shift_in;
					y_reg = y_in - x_shift_in;
					z_reg = z_in + const_atan;
				end else begin
					x_reg = x_in - y_shift_in;
					y_reg = y_in + x_shift_in;
					z_reg = z_in - const_atan;
				end
			end
	end
	
	assign x_out = x_reg[31:0];
	assign y_out = y_reg[31:0];
	assign z_out = z_reg[31:0];
endmodule 

