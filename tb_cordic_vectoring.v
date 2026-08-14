`timescale 1ns/1ps

module tb_cordic_vectoring;

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

//////////////////////////////////////////////////
// Clock
//////////////////////////////////////////////////

initial
begin
    clk=0;
    forever #5 clk=~clk;
end


//////////////////////////////////////////////////
// Input vectors
//////////////////////////////////////////////////

reg signed [31:0] x_table [0:15];
reg signed [31:0] y_table [0:15];

initial
begin

    x_table[0]=32'h376CF5D0;
    y_table[0]=32'hE0000000;

    x_table[1]=32'h2D413CCD;
    y_table[1]=32'hD2BEC333;

    x_table[2]=32'h20000000;
    y_table[2]=32'hC8930A30;

    x_table[3]=32'h00000000;
    y_table[3]=32'hC0000000;

    x_table[4]=32'hE0000000;
    y_table[4]=32'hC8930A30;

    x_table[5]=32'hD2BEC333;
    y_table[5]=32'hD2BEC333;

    x_table[6]=32'hC8930A30;
    y_table[6]=32'hE0000000;

    x_table[7]=32'hC0000000;
    y_table[7]=32'h00000000;

    x_table[8]=32'hC8930A30;
    y_table[8]=32'h20000000;

    x_table[9]=32'hD2BEC333;
    y_table[9]=32'h2D413CCD;

    x_table[10]=32'hE0000000;
    y_table[10]=32'h376CF5D0;

    x_table[11]=32'h00000000;
    y_table[11]=32'h40000000;

    x_table[12]=32'h20000000;
    y_table[12]=32'h376CF5D0;

    x_table[13]=32'h2D413CCD;
    y_table[13]=32'h2D413CCD;

    x_table[14]=32'h376CF5D0;
    y_table[14]=32'h20000000;

    x_table[15]=32'h40000000;
    y_table[15]=32'h00000000;

end


//////////////////////////////////////////////////
// Stimulus
//////////////////////////////////////////////////

initial
begin

    fp=$fopen("cordic_test_vectoring.txt","w");

    $fwrite(fp,
    "X_input      Y_input      X_out      Y_out      Z_out\n");

    rst=1;

    load_en_in=0;
    enable_output=0;

    mode=1;          // vectoring

    data_in_x=0;
    data_in_y=0;
    data_in_z=0;

    #100;

    rst=0;

    #20;

    for(i=0;i<16;i=i+1)
    begin

        @(posedge clk);

        data_in_x=x_table[i];
        data_in_y=y_table[i];
        data_in_z=0;

        load_en_in=1;
        enable_output=1;

        @(posedge clk);

        load_en_in=0;

        wait(done_stage_19);

        @(posedge clk);

        $fwrite(
        fp,
        "%h   %h   %h   %h   %h\n",
        data_in_x,
        data_in_y,
        data_out_x,
        data_out_y,
        data_out_z
        );

        #20;

    end

    $fclose(fp);

    $display("Vectoring simulation completed");

    $stop;

end

endmodule