module CORDIC_SoC (
    input CLOCK_50,
    input [1:0] KEY,
    output [15:0] LEDR,
	 input [15:0] SW,
	 inout [1:0] GPIO_1
);
 system uut (
		.clk_clk(CLOCK_50),                       //                    clk.clk
		.reset_reset_n(KEY[0]),		//                  reset.reset_n
		.switches_0_export(SW), // switches_0.export
		.leds_0_export(LEDR),
      .start_export(KEY[1]),      //      start.export
		.lcd_sda_export(GPIO_1[0]),    //    lcd_sda.export
      .lcd_scl_export(GPIO_1[1])	
	);

endmodule 