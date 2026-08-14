module control_slave_cordic (
    input wire iClk,
    input wire iReset_n,
    input wire iChip_select_n,
    input wire iWrite_n,
    input wire iRead_n,
    input wire [3:0] iAddress,
    input wire [31:0] iWrite_data,
    output reg [31:0] oRead_data,

    output reg oStart,
    output reg oMode,
    output reg oIrq_en,
    output reg signed [31:0] oX_in,
    output reg signed [31:0] oY_in,
    output reg signed [31:0] oZ_in,

    input wire iBusy,
    input wire iDone,
    input wire signed [31:0] iX_out,
    input wire signed [31:0] iY_out,
    input wire signed [31:0] iZ_out,
    output wire oIrq
);
    localparam [3:0] ADDR_CONTROL = 4'h0;
    localparam [3:0] ADDR_STATUS  = 4'h1;
    localparam [3:0] ADDR_X_IN    = 4'h2;
    localparam [3:0] ADDR_Y_IN    = 4'h3;
    localparam [3:0] ADDR_Z_IN    = 4'h4;
    localparam [3:0] ADDR_X_OUT   = 4'h5;
    localparam [3:0] ADDR_Y_OUT   = 4'h6;
    localparam [3:0] ADDR_Z_OUT   = 4'h7;

    wire write_en = ~iChip_select_n & ~iWrite_n;
    wire read_en = ~iChip_select_n & ~iRead_n;
    wire start_pulse = write_en && (iAddress == ADDR_CONTROL) && iWrite_data[0];
    wire clear_done = write_en && (iAddress == ADDR_STATUS) && iWrite_data[1];

    reg done_reg;
    reg signed [31:0] x_out_reg;
    reg signed [31:0] y_out_reg;
    reg signed [31:0] z_out_reg;

    assign oIrq = oIrq_en && done_reg;

    always @(posedge iClk or negedge iReset_n) begin
        if (~iReset_n) begin
            oStart <= 1'b0;
            oMode <= 1'b0;
            oIrq_en <= 1'b0;
            oX_in <= 32'sd0;
            oY_in <= 32'sd0;
            oZ_in <= 32'sd0;
            done_reg <= 1'b0;
            x_out_reg <= 32'sd0;
            y_out_reg <= 32'sd0;
            z_out_reg <= 32'sd0;
        end else begin
            oStart <= 1'b0;

            if (write_en) begin
                case (iAddress)
                    ADDR_CONTROL: begin
                        oMode <= iWrite_data[1];
                        oIrq_en <= iWrite_data[2];
                        if (iWrite_data[0]) begin
                            oStart <= 1'b1;
                        end
                    end
                    ADDR_X_IN: oX_in <= iWrite_data;
                    ADDR_Y_IN: oY_in <= iWrite_data;
                    ADDR_Z_IN: oZ_in <= iWrite_data;
                    ADDR_STATUS: begin
                        if (iWrite_data[1]) begin
                            done_reg <= 1'b0;
                        end
                    end
                    default: begin
                        oMode <= oMode;
                        oIrq_en <= oIrq_en;
                        oX_in <= oX_in;
                        oY_in <= oY_in;
                        oZ_in <= oZ_in;
                        done_reg <= done_reg;
                    end
                endcase
            end

            if (iDone) begin
                done_reg <= 1'b1;
                x_out_reg <= iX_out;
                y_out_reg <= iY_out;
                z_out_reg <= iZ_out;
            end else if (start_pulse || clear_done) begin
                done_reg <= 1'b0;
            end
        end
    end

    always @* begin
        oRead_data = 32'd0;
        if (read_en) begin
            case (iAddress)
                ADDR_CONTROL: oRead_data = {29'd0, oIrq_en, oMode, 1'b0};
                ADDR_STATUS:  oRead_data = {29'd0, oIrq, done_reg, iBusy};
                ADDR_X_IN:    oRead_data = oX_in;
                ADDR_Y_IN:    oRead_data = oY_in;
                ADDR_Z_IN:    oRead_data = oZ_in;
                ADDR_X_OUT:   oRead_data = x_out_reg;
                ADDR_Y_OUT:   oRead_data = y_out_reg;
                ADDR_Z_OUT:   oRead_data = z_out_reg;
                default:      oRead_data = 32'd0;
            endcase
        end
    end
endmodule