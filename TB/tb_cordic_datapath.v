`timescale 1ns/1ps

module tb_cordic_datapath;

reg clk;
reg rst;
reg load_en_in;
reg enable_output;
reg mode;

reg signed [31:0] data_in_x;
reg signed [31:0] data_in_y;
reg signed [31:0] data_in_z;

wire signed [31:0] data_out_x;
wire signed [31:0] data_out_y;
wire signed [31:0] data_out_z;

wire done_stage_19;

integer fp;
integer i;

Cordic_Datapath DUT
(
    .clk(clk),
    .rst(rst),
    .load_en_in(load_en_in),
    .enable_output(enable_output),
    .mode(mode),
    .data_in_x(data_in_x),
    .data_in_y(data_in_y),
    .data_in_z(data_in_z),
    .data_out_x(data_out_x),
    .data_out_y(data_out_y),
    .data_out_z(data_out_z),
    .done_stage_19(done_stage_19)
);

/////////////////////////////////////
// Clock
/////////////////////////////////////

initial
begin
    clk=0;
    forever #5 clk=~clk;
end


/////////////////////////////////////
// Test vectors
/////////////////////////////////////

reg signed [31:0] z_table [0:30];

initial
begin

    z_table[0]=32'h3AAAAAAB; //330
    z_table[1]=32'h38000000; //315
    z_table[2]=32'h35555556; //300
    z_table[3]=32'h30000000; //270
    z_table[4]=32'h2AAAAAAB; //240
    z_table[5]=32'h28000000; //225
    z_table[6]=32'h25555556; //210
    z_table[7]=32'h20000000; //180
    z_table[8]=32'h1AAAAAAB; //150
    z_table[9]=32'h18000000; //135
    z_table[10]=32'h15555556;//120
    z_table[11]=32'h10000000;//90
    z_table[12]=32'h0AAAAAAB;//60
    z_table[13]=32'h08000000;//45
    z_table[14]=32'h05555556;//30
    z_table[15]=32'h00000000;//0

    z_table[16]=32'hFAAAAAAB;//-30
    z_table[17]=32'hF8000000;//-45
    z_table[18]=32'hF5555556;//-60
    z_table[19]=32'hF0000000;//-90
    z_table[20]=32'hEAAAAAAB;//-120
    z_table[21]=32'hE8000000;//-135
    z_table[22]=32'hE5555556;//-150
    z_table[23]=32'hE0000000;//-180
    z_table[24]=32'hDAAAAAAB;//-210
    z_table[25]=32'hD8000000;//-225
    z_table[26]=32'hD5555556;//-240
    z_table[27]=32'hD0000000;//-270
    z_table[28]=32'hCAAAAAAB;//-300
    z_table[29]=32'hC8000000;//-315
    z_table[30]=32'hC5555556;//-330

end


/////////////////////////////////////
// Stimulus
/////////////////////////////////////

initial
begin

    fp=$fopen("cordic_output.txt","w");

    $fwrite(fp,
    "Z_input       X_out       Y_out       Z_out\n");

    rst=1;
    load_en_in=0;
    enable_output=0;
    mode=0;

    data_in_x=0;
    data_in_y=0;
    data_in_z=0;

    #100;

    rst=0;

    #20;

    for(i=0;i<31;i=i+1)
    begin

        @(posedge clk);

        data_in_z=z_table[i];

        load_en_in=1;
        enable_output=1;

        @(posedge clk);

        load_en_in=0;

        wait(done_stage_19);

        @(posedge clk);

        $fwrite(
        fp,
        "%h   %h   %h   %h\n",
        data_in_z,
        data_out_x,
        data_out_y,
        data_out_z
        );

        #20;

    end

    $fclose(fp);

    $display("Simulation finished");

    $stop;

end

endmodule
