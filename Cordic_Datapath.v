module Cordic_Datapath (
    input wire clk,
    input wire rst,
    input wire load_en_in,
	input wire enable_output,
    input wire mode,
    input wire signed [31:0] data_in_x,
    input wire signed [31:0] data_in_y,
    input wire signed [31:0] data_in_z,
    output wire signed [31:0] data_out_x,
    output wire signed [31:0] data_out_y,
    output wire signed [31:0] data_out_z,
	 output wire done_stage_19
);
	//Iterations
	 reg signed [31:0] x_start, y_start, z_start;
	 reg signed valid_bit_start;
	 //
    wire signed [31:0] x_pipe [0:19];
    wire signed [31:0] y_pipe [0:19];
    wire signed [31:0] z_pipe [0:19];
    wire mode_pipe [0:19];
	 wire valid_bit_pipe [0:19];
     wire signed [31:0] x_pre, y_pre, angle_pre;
	 //
	 wire signed [31:0] out_exe1_x, out_exe1_y, out_exe1_z;
	 wire signed [31:0] out_exe2_x, out_exe2_y, out_exe2_z;
	 wire signed [31:0] out_exe3_x, out_exe3_y, out_exe3_z;
	 wire signed [31:0] out_exe4_x, out_exe4_y, out_exe4_z;
	 wire signed [31:0] out_exe5_x, out_exe5_y, out_exe5_z;
	 wire signed [31:0] out_exe6_x, out_exe6_y, out_exe6_z;
	 wire signed [31:0] out_exe7_x, out_exe7_y, out_exe7_z;
	 wire signed [31:0] out_exe8_x, out_exe8_y, out_exe8_z;
	 wire signed [31:0] out_exe9_x, out_exe9_y, out_exe9_z;
	 wire signed [31:0] out_exe10_x, out_exe10_y, out_exe10_z;
	 wire signed [31:0] out_exe11_x, out_exe11_y, out_exe11_z;
	 wire signed [31:0] out_exe12_x, out_exe12_y, out_exe12_z;
	 wire signed [31:0] out_exe13_x, out_exe13_y, out_exe13_z;
	 wire signed [31:0] out_exe14_x, out_exe14_y, out_exe14_z;
	 wire signed [31:0] out_exe15_x, out_exe15_y, out_exe15_z;
	 wire signed [31:0] out_exe16_x, out_exe16_y, out_exe16_z;
	 wire signed [31:0] out_exe17_x, out_exe17_y, out_exe17_z;
	 wire signed [31:0] out_exe18_x, out_exe18_y, out_exe18_z;
	 wire signed [31:0] out_exe19_x, out_exe19_y, out_exe19_z;
	 wire signed [31:0] out_exe20_x, out_exe20_y, out_exe20_z;
    //ARCTAN LUT
	 
   wire signed [31:0] atan_table [0:19];

	assign atan_table[00] = 32'sh08000000; // atan(2^0)   ≈ 45°
	assign atan_table[01] = 32'sh04B90147; // atan(2^-1)  ≈ 26.565°
	assign atan_table[02] = 32'sh027ECE16; // atan(2^-2)  ≈ 14.036°
	assign atan_table[03] = 32'sh01444475; // atan(2^-3)  ≈ 7.125°
	assign atan_table[04] = 32'sh00A2C350; // atan(2^-4)  ≈ 3.576°
	assign atan_table[05] = 32'sh00517CC1; // atan(2^-5)  ≈ 1.790°
	assign atan_table[06] = 32'sh0028BE2A; // atan(2^-6)  ≈ 0.895°
	assign atan_table[07] = 32'sh00145F29; // atan(2^-7)  ≈ 0.448°
	assign atan_table[08] = 32'sh000A2F97; // atan(2^-8)  ≈ 0.224°
	assign atan_table[09] = 32'sh000517CB; // atan(2^-9)  ≈ 0.112°
	assign atan_table[10] = 32'sh00028BE5; // atan(2^-10) ≈ 0.056°
	assign atan_table[11] = 32'sh000145F2; // atan(2^-11) ≈ 0.028°
	assign atan_table[12] = 32'sh0000A2F9; // atan(2^-12) ≈ 0.014°
	assign atan_table[13] = 32'sh0000517C; // atan(2^-13) ≈ 0.007°
	assign atan_table[14] = 32'sh000028BE; // atan(2^-14) ≈ 0.0035°
	assign atan_table[15] = 32'sh0000145F; // atan(2^-15) ≈ 0.0017°
	assign atan_table[16] = 32'sh00000A2F; // atan(2^-16) ≈ 0.0009°
	assign atan_table[17] = 32'sh00000517; // atan(2^-17) ≈ 0.00045°
	assign atan_table[18] = 32'sh0000028B; // atan(2^-18) ≈ 0.00022°
	assign atan_table[19] = 32'sh00000145; // atan(2^-19) ≈ 0.00011°
	//
	//
    pre_cordic pre_block(
        .mode(mode),
        .data_in_x(data_in_x),
        .data_in_y(data_in_y),
        .data_in_z(data_in_z),
        .x_pre(x_pre),
        .y_pre(y_pre),
        .angle_pre(angle_pre)
    );
	//Load input
    always @(posedge clk or posedge rst)
    begin
        if (rst) begin
            x_start <= 32'b0;
            y_start <= 32'b0;
            z_start <= 32'b0;
				valid_bit_start <= 1'b0;
          end else if (load_en_in == 1'b1) begin
                x_start <= x_pre;
                y_start <= y_pre;
                z_start <= angle_pre;
                valid_bit_start <= 1'b1;
		  end else begin
				x_start <= x_start;
            y_start <= y_start;
            z_start <= z_start;
				valid_bit_start <= 1'b0;
        end
    end

    //Stage0
    Execute_Cordic exe_Block1 (
        .x_in(x_start),
        .y_in(y_start),
        .z_in(z_start),
        .const_atan(atan_table[0]),
        .x_shift_in(x_start >>> 0),
        .y_shift_in(y_start >>> 0),
        .mode(mode),
        .x_out(out_exe1_x),
        .y_out(out_exe1_y),
        .z_out(out_exe1_z)
    );
    Register_Cordic register1 (
        .clk(clk),
        .rst(rst),
        .data_in1(out_exe1_x),
        .data_in2(out_exe1_y),
        .data_in3(out_exe1_z),
        .mode_in(mode),
		  .valid_bit_in(valid_bit_start), 
        .data_out1(x_pipe[0]),
        .data_out2(y_pipe[0]),
        .data_out3(z_pipe[0]),
        .mode_out(mode_pipe[0]),
		  .valid_bit_out(valid_bit_pipe[0])
    );
    //Stage1
    Execute_Cordic exe_block2 (
        .x_in(x_pipe[0]),
        .y_in(y_pipe[0]),
        .z_in(z_pipe[0]),
        .const_atan(atan_table[1]),
        .x_shift_in(x_pipe[0] >>> 1),
        .y_shift_in(y_pipe[0] >>> 1),
        .mode(mode_pipe[0]),
        .x_out(out_exe2_x),
        .y_out(out_exe2_y),
        .z_out(out_exe2_z)
    );
    Register_Cordic register2 (
        .clk(clk),
        .rst(rst),
        .data_in1(out_exe2_x),
        .data_in2(out_exe2_y),
        .data_in3(out_exe2_z),
        .mode_in(mode_pipe[0]),
		  .valid_bit_in(valid_bit_pipe[0]), 
        .data_out1(x_pipe[1]),
        .data_out2(y_pipe[1]),
        .data_out3(z_pipe[1]),
        .mode_out(mode_pipe[1]),
		  .valid_bit_out(valid_bit_pipe[1])
    );
    //stage2
    Execute_Cordic exe_block3 (
        .x_in(x_pipe[1]),
        .y_in(y_pipe[1]),
        .z_in(z_pipe[1]),
        .const_atan(atan_table[2]),
        .x_shift_in(x_pipe[1] >>> 2),
        .y_shift_in(y_pipe[1] >>> 2),
        .mode(mode_pipe[1]),
        .x_out(out_exe3_x),
        .y_out(out_exe3_y),
        .z_out(out_exe3_z)
    );
    Register_Cordic register3 (
        .clk(clk),
        .rst(rst),
        .data_in1(out_exe3_x),
        .data_in2(out_exe3_y),
        .data_in3(out_exe3_z),
        .mode_in(mode_pipe[1]),
		  .valid_bit_in(valid_bit_pipe[1]),  
        .data_out1(x_pipe[2]),
        .data_out2(y_pipe[2]),
        .data_out3(z_pipe[2]),
        .mode_out(mode_pipe[2]),
		  .valid_bit_out(valid_bit_pipe[2])
    );
    //stage3
    Execute_Cordic exe_block4 (
        .x_in(x_pipe[2]),
        .y_in(y_pipe[2]),
        .z_in(z_pipe[2]),
        .const_atan(atan_table[3]),
        .x_shift_in(x_pipe[2] >>> 3),
        .y_shift_in(y_pipe[2] >>> 3),
        .mode(mode_pipe[2]),
        .x_out(out_exe4_x),
        .y_out( out_exe4_y),
        .z_out( out_exe4_z)
    );
    Register_Cordic register4 (
        .clk(clk),
        .rst(rst),
        .data_in1( out_exe4_x),
        .data_in2( out_exe4_y),
        .data_in3( out_exe4_z),
        .mode_in( mode_pipe[2]),
		  .valid_bit_in(valid_bit_pipe[2]), 
        .data_out1( x_pipe[3]),
        .data_out2( y_pipe[3]),
        .data_out3( z_pipe[3]),
        .mode_out( mode_pipe[3]),
		  .valid_bit_out(valid_bit_pipe[3])
    );
    //
    Execute_Cordic exe_block5 (
        .x_in( x_pipe[3]),
        .y_in( y_pipe[3]),
        .z_in( z_pipe[3]),
        .const_atan( atan_table[4]),
        .x_shift_in( x_pipe[3] >>> 4),
        .y_shift_in( y_pipe[3] >>> 4),
        .mode( mode_pipe[3]),
        .x_out( out_exe5_x),
        .y_out( out_exe5_y),
        .z_out( out_exe5_z)
    );
    Register_Cordic register5 (
        .clk(clk),
        .rst(rst),
        .data_in1( out_exe5_x),
        .data_in2( out_exe5_y),
        .data_in3( out_exe5_z),
        .mode_in( mode_pipe[3]),
		  .valid_bit_in(valid_bit_pipe[3]), 
        .data_out1( x_pipe[4]),
        .data_out2( y_pipe[4]),
        .data_out3( z_pipe[4]),
        .mode_out(  mode_pipe[4]),
		  .valid_bit_out(valid_bit_pipe[4])
    );
    //
    Execute_Cordic exe_block6 (
        .x_in( x_pipe[4]),
        .y_in( y_pipe[4]),
        .z_in( z_pipe[4]),
        .const_atan( atan_table[5]),
        .x_shift_in( x_pipe[4] >>> 5),
        .y_shift_in( y_pipe[4] >>> 5),
        .mode( mode_pipe[4]),
        .x_out( out_exe6_x),
        .y_out( out_exe6_y),
        .z_out( out_exe6_z)
    );
    Register_Cordic register6 (
        .clk(clk),
        .rst(rst),
        .data_in1( out_exe6_x),
        .data_in2( out_exe6_y),
        .data_in3( out_exe6_z),
        .mode_in( mode_pipe[4]),
		  .valid_bit_in(valid_bit_pipe[4]), 
        .data_out1( x_pipe[5]),
        .data_out2( y_pipe[5]),
        .data_out3( z_pipe[5]),
        .mode_out( mode_pipe[5]),
		  .valid_bit_out(valid_bit_pipe[5])
    );
    //stage6
    Execute_Cordic exe_block7 (
        .x_in( x_pipe[5]),
        .y_in( y_pipe[5]),
        .z_in( z_pipe[5]),
        .const_atan( atan_table[6]),
        .x_shift_in( x_pipe[5] >>> 6),
        .y_shift_in( y_pipe[5] >>> 6),
        .mode( mode_pipe[5]),
        .x_out( out_exe7_x),   
        .y_out( out_exe7_y),
        .z_out( out_exe7_z)
    );
    Register_Cordic register7 (
        .clk(clk),
        .rst(rst),
        .data_in1( out_exe7_x),
        .data_in2(  out_exe7_y),
        .data_in3( out_exe7_z),
        .mode_in( mode_pipe[5]),
		  .valid_bit_in(valid_bit_pipe[5]), 
        .data_out1( x_pipe[6]),
        .data_out2( y_pipe[6]),
        .data_out3( z_pipe[6]),
        .mode_out( mode_pipe[6]),
		  .valid_bit_out(valid_bit_pipe[6])
    );	 
    //stage7
    Execute_Cordic exe_block8 (
        .x_in( x_pipe[6]),
        .y_in( y_pipe[6]),
        .z_in( z_pipe[6]),
        .const_atan( atan_table[7]),
        .x_shift_in( x_pipe[6] >>> 7),
        .y_shift_in( y_pipe[6] >>> 7),
        .mode( mode_pipe[6]),
        .x_out( out_exe8_x),
        .y_out( out_exe8_y),
        .z_out( out_exe8_z)
    );
    Register_Cordic register8 (
        .clk(clk),
        .rst(rst),
        .data_in1( out_exe8_x),
        .data_in2( out_exe8_y),
        .data_in3( out_exe8_z),
        .mode_in( mode_pipe[6]),
		  .valid_bit_in(valid_bit_pipe[6]), 
        .data_out1( x_pipe[7]),
        .data_out2( y_pipe[7]),
        .data_out3( z_pipe[7]),
        .mode_out( mode_pipe[7]),
		  .valid_bit_out(valid_bit_pipe[7])
    );
     //stage8   
    Execute_Cordic exe_block9 (
        .x_in( x_pipe[7]),
        .y_in( y_pipe[7]),
        .z_in( z_pipe[7]),
        .const_atan( atan_table[8]),
        .x_shift_in( x_pipe[7] >>> 8),
        .y_shift_in( y_pipe[7] >>> 8),
        .mode( mode_pipe[7]),
        .x_out( out_exe9_x),
        .y_out( out_exe9_y),
        .z_out( out_exe9_z)
    );
    Register_Cordic register9 (
        .clk(clk),
        .rst(rst),
        .data_in1( out_exe9_x),
        .data_in2( out_exe9_y),
        .data_in3( out_exe9_z),
        .mode_in( mode_pipe[7]),
		  .valid_bit_in(valid_bit_pipe[7]), 
        .data_out1( x_pipe[8]),
        .data_out2( y_pipe[8]),
        .data_out3( z_pipe[8]),
        .mode_out( mode_pipe[8]),
		  .valid_bit_out(valid_bit_pipe[8])
    );	 
    //stage9
    Execute_Cordic exe_block10 (
        .x_in( x_pipe[8]),
        .y_in( y_pipe[8]),
        .z_in( z_pipe[8]),
        .const_atan( atan_table[9]),
        .x_shift_in( x_pipe[8] >>> 9),
        .y_shift_in( y_pipe[8] >>> 9),
        .mode( mode_pipe[8]),
        .x_out( out_exe10_x),
        .y_out( out_exe10_y),
        .z_out( out_exe10_z)
    );
    Register_Cordic register10 (
        .clk(clk),
        .rst(rst),
        .data_in1( out_exe10_x),
        .data_in2( out_exe10_y),
        .data_in3( out_exe10_z),
        .mode_in( mode_pipe[8]), 
		  .valid_bit_in(valid_bit_pipe[8]),
        .data_out1( x_pipe[9]),
        .data_out2( y_pipe[9]),
        .data_out3( z_pipe[9]),
        .mode_out( mode_pipe[9]),
		  .valid_bit_out(valid_bit_pipe[9])
    );	 
    //stage10
    Execute_Cordic exe_block11 (
        .x_in( x_pipe[9]),
        .y_in(  y_pipe[9]),
        .z_in( z_pipe[9]),
        .const_atan( atan_table[10]),
        .x_shift_in( x_pipe[9] >>> 10),
        .y_shift_in( y_pipe[9] >>> 10),
        .mode( mode_pipe[9]),
        .x_out( out_exe11_x),
        .y_out( out_exe11_y),
        .z_out( out_exe11_z)
    );
    Register_Cordic register11 (
        .clk(clk),
        .rst(rst),
        .data_in1( out_exe11_x),
        .data_in2( out_exe11_y),
        .data_in3( out_exe11_z),
        .mode_in( mode_pipe[9]),
		  .valid_bit_in(valid_bit_pipe[9]), 
        .data_out1( x_pipe[10]),
        .data_out2( y_pipe[10]),
        .data_out3( z_pipe[10]),
        .mode_out( mode_pipe[10]),
		  .valid_bit_out(valid_bit_pipe[10])
    ); 
    //Stage11  
    Execute_Cordic exe_block12 (
        .x_in( x_pipe[10]),
        .y_in( y_pipe[10]),
        .z_in( z_pipe[10]),
        .const_atan( atan_table[11]),
        .x_shift_in( x_pipe[10] >>> 11),
        .y_shift_in( y_pipe[10] >>> 11),
        .mode( mode_pipe[10]),
        .x_out( out_exe12_x),
        .y_out( out_exe12_y),
        .z_out( out_exe12_z)
    );
    Register_Cordic register12 (
        .clk(clk),
        .rst(rst),
        .data_in1( out_exe12_x),
        .data_in2( out_exe12_y),
        .data_in3( out_exe12_z),
        .mode_in( mode_pipe[10]),
		  .valid_bit_in(valid_bit_pipe[10]), 
        .data_out1(  x_pipe[11]),
        .data_out2( y_pipe[11]),
        .data_out3( z_pipe[11]),
        .mode_out( mode_pipe[11]),
		  .valid_bit_out(valid_bit_pipe[11])
    ); 
    //Stage12
    Execute_Cordic exe_block13 (
        .x_in( x_pipe[11]),
        .y_in( y_pipe[11]),
        .z_in( z_pipe[11]),
        .const_atan( atan_table[12]),
        .x_shift_in( x_pipe[11] >>> 12),
        .y_shift_in( y_pipe[11] >>> 12),
        .mode( mode_pipe[11]),
        .x_out( out_exe13_x),
        .y_out( out_exe13_y),
        .z_out( out_exe13_z)
    );
    Register_Cordic register13 (
        .clk(clk),
        .rst(rst),
        .data_in1( out_exe13_x),
        .data_in2( out_exe13_y),
        .data_in3( out_exe13_z),
        .mode_in( mode_pipe[11]),
		  .valid_bit_in(valid_bit_pipe[11]), 
        .data_out1( x_pipe[12]),
        .data_out2( y_pipe[12]),
        .data_out3( z_pipe[12]),
        .mode_out( mode_pipe[12]),
		  .valid_bit_out(valid_bit_pipe[12])
    );
    //Stage13
    Execute_Cordic exe_block14 (
        .x_in(x_pipe[12]),
        .y_in(y_pipe[12]),
        .z_in(z_pipe[12]),
        .const_atan(atan_table[13]),
        .x_shift_in(x_pipe[12] >>> 13),
        .y_shift_in(y_pipe[12] >>> 13),
        .mode(mode_pipe[12]),
        .x_out(out_exe14_x),
        .y_out(out_exe14_y),
        .z_out(out_exe14_z)
    );
    Register_Cordic register14 (
        .clk(clk),
        .rst(rst),
        .data_in1(out_exe14_x),
        .data_in2(out_exe14_y),
        .data_in3(out_exe14_z),
        .mode_in(mode_pipe[12]),
		  .valid_bit_in(valid_bit_pipe[12]), 
        .data_out1(x_pipe[13]),
        .data_out2(y_pipe[13]),
        .data_out3(z_pipe[13]),
        .mode_out(mode_pipe[13]),
		  .valid_bit_out(valid_bit_pipe[13])
    );
    //Stage14  
    Execute_Cordic exe_block15 (
        .x_in(x_pipe[13]),
        .y_in(y_pipe[13]),
        .z_in(z_pipe[13]),
        .const_atan(atan_table[14]),
        .x_shift_in(x_pipe[13] >>> 14),
        .y_shift_in(y_pipe[13] >>> 14),
        .mode(mode_pipe[13]),
        .x_out(out_exe15_x),
        .y_out(out_exe15_y),
        .z_out(out_exe15_z)
    );
    Register_Cordic register15 (
        .clk(clk),
        .rst(rst),
        .data_in1(out_exe15_x),
        .data_in2(out_exe15_y),
        .data_in3(out_exe15_z),
        .mode_in(mode_pipe[13]),
		  .valid_bit_in(valid_bit_pipe[13]), 
        .data_out1(x_pipe[14]),
        .data_out2(y_pipe[14]),
        .data_out3(z_pipe[14]),
        .mode_out(mode_pipe[14]),
		  .valid_bit_out(valid_bit_pipe[14])
    );
    //Stage15   
    Execute_Cordic exe_block16 (
        .x_in(x_pipe[14]),
        .y_in(y_pipe[14]),
        .z_in(z_pipe[14]),
        .const_atan(atan_table[15]),
        .x_shift_in(x_pipe[14] >>> 15),
        .y_shift_in(y_pipe[14] >>> 15),
        .mode( mode_pipe[14]),
        .x_out(out_exe16_x),
        .y_out(out_exe16_y),
        .z_out(out_exe16_z)
    );
    Register_Cordic register16 (
        .clk(clk),
        .rst(rst),
        .data_in1(out_exe16_x),
        .data_in2(out_exe16_y),
        .data_in3(out_exe16_z),
        .mode_in(mode_pipe[14]),
		  .valid_bit_in(valid_bit_pipe[14]), 
        .data_out1(x_pipe[15]),
        .data_out2(y_pipe[15]),
        .data_out3(z_pipe[15]),
        .mode_out(mode_pipe[15]),
		  .valid_bit_out(valid_bit_pipe[15])
    );
    //Stage16
    Execute_Cordic exe_block17 (
        .x_in(x_pipe[15]),
        .y_in(y_pipe[15]),
        .z_in(z_pipe[15]),
        .const_atan(atan_table[16]),
        .x_shift_in(x_pipe[15] >>> 16),
        .y_shift_in(y_pipe[15] >>> 16),
        .mode(mode_pipe[15]),
        .x_out(out_exe17_x),
        .y_out(out_exe17_y),
        .z_out(out_exe17_z)
    );
    Register_Cordic register17 (
        .clk(clk),
        .rst(rst),
        .data_in1(out_exe17_x),
        .data_in2(out_exe17_y),
        .data_in3(out_exe17_z),
        .mode_in(mode_pipe[15]),
		  .valid_bit_in(valid_bit_pipe[15]), 
        .data_out1(x_pipe[16]),
        .data_out2(y_pipe[16]),
        .data_out3(z_pipe[16]),
        .mode_out(mode_pipe[16]),
		  .valid_bit_out(valid_bit_pipe[16])
    );
    //Stage17
    Execute_Cordic exe_block18 (
        .x_in(x_pipe[16]),
        .y_in(y_pipe[16]),
        .z_in(z_pipe[16]),
        .const_atan(atan_table[17]),
        .x_shift_in(x_pipe[16] >>> 17),
        .y_shift_in(y_pipe[16] >>> 17),
        .mode(mode_pipe[16]),
        .x_out(out_exe18_x),
        .y_out(out_exe18_y),
        .z_out(out_exe18_z)
    );
    Register_Cordic register18 (
        .clk(clk),
        .rst(rst),
        .data_in1(out_exe18_x),
        .data_in2(out_exe18_y),
        .data_in3(out_exe18_z),
        .mode_in(mode_pipe[16]),
		  .valid_bit_in(valid_bit_pipe[16]), 
        .data_out1(x_pipe[17]),
        .data_out2(y_pipe[17]),
        .data_out3(z_pipe[17]),
        .mode_out(mode_pipe[17]),
		  .valid_bit_out(valid_bit_pipe[17])
    );
    //Stage18 
    Execute_Cordic exe_block19 (
        .x_in(x_pipe[17]),
        .y_in(y_pipe[17]),
        .z_in(z_pipe[17]),
        .const_atan(atan_table[18]),
        .x_shift_in(x_pipe[17] >>> 18),
        .y_shift_in(y_pipe[17] >>> 18),
        .mode(mode_pipe[17]),
        .x_out(out_exe19_x),
        .y_out(out_exe19_y),
        .z_out(out_exe19_z)
    );
    Register_Cordic register19 (
        .clk(clk),
        .rst(rst),
        .data_in1(out_exe19_x),
        .data_in2(out_exe19_y),
        .data_in3(out_exe19_z),
        .mode_in(mode_pipe[17]),
		  .valid_bit_in(valid_bit_pipe[17]), 
        .data_out1(x_pipe[18]),
        .data_out2(y_pipe[18]),
        .data_out3(z_pipe[18]),
        .mode_out(mode_pipe[18]),
		  .valid_bit_out(valid_bit_pipe[18])
    );
    //Stage19    
    Execute_Cordic exe_block20 (
        .x_in(x_pipe[18]),
        .y_in(y_pipe[18]),
        .z_in(z_pipe[18]),
        .const_atan(atan_table[19]),
        .x_shift_in(x_pipe[18] >>> 19),
        .y_shift_in(y_pipe[18] >>> 19),
        .mode(mode_pipe[18]),
        .x_out(out_exe20_x),
        .y_out(out_exe20_y),
        .z_out(out_exe20_z)
    );
	 
     //debug
     assign done_stage_19 = valid_bit_pipe[18];
	 assign data_out_x = out_exe20_x;
	 assign data_out_y = out_exe20_y;
	 assign data_out_z = out_exe20_z;
	 
endmodule