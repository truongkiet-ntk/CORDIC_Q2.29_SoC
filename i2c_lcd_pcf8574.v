// =========================================================
// LCD I2C dùng PCF8574 - ĐÃ ĐƯỢC NÂNG CẤP AUTO-REFRESH
// Tự động nhận dữ liệu Fixed-point và chuyển sang ASCII
// =========================================================
module i2c_lcd_pcf8574 #(
    parameter I2C_ADDR = 7'h27 // Địa chỉ module I2C LCD (thường là 0x27 hoặc 0x3F)
)(
    input  clk,
    input  rst_n,

    // DỮ LIỆU ĐỘNG TỪ SHT30 TRUYỀN VÀO (Ví dụ: 285 = 28.5, 620 = 62.0)
    input [15:0] temp_val, 
    input [15:0] humi_val,

    // Giao tiếp vật lý I2C
    input  sda_in,
    output sda_drive_low,
    output scl_drive_low
);

    localparam integer WAIT_POWER   = 1000000;  // 20ms @ 50MHz
    localparam integer WAIT_REFRESH = 10000000; // 200ms @ 50MHz (Thời gian chờ làm mới)
    localparam integer WAIT_5MS     = 250000;
    localparam integer WAIT_2MS     = 100000;
    localparam integer WAIT_50US    = 2500;
    localparam integer WAIT_200US   = 10000;

    localparam [3:0]
        ST_POWER       = 4'd0,
        ST_INIT_LOAD   = 4'd1,
        ST_BYTE_LOAD   = 4'd2,
        ST_SEND_E1     = 4'd3,
        ST_WAIT_E1     = 4'd4,
        ST_SEND_E0     = 4'd5,
        ST_WAIT_E0     = 4'd6,
        ST_AFTER_NIB   = 4'd7,
        ST_DONE        = 4'd8;

    localparam [1:0]
        RET_INIT      = 2'd0,
        RET_BYTE_LOW  = 2'd1,
        RET_BYTE_DONE = 2'd2;

    localparam [5:0] TOTAL_BYTES = 6'd38;

    reg [3:0] state;
    reg [1:0] ret_state;

    reg [31:0] cnt;
    reg [31:0] post_delay;

    reg [2:0] init_step;
    reg [5:0] idx;

    reg [7:0] cur_byte;
    reg cur_rs;
    reg [3:0] cur_nibble;

    reg tx_start;
    reg [7:0] tx_data;

    wire tx_busy;
    wire tx_done;

    wire [8:0] rom_data;
    assign rom_data = lcd_rom(idx);

    i2c_write_byte #(
        .DIVIDER(250)       // Khoảng 100kHz với clock 50MHz
    ) u_i2c (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (tx_start),
        .addr          (I2C_ADDR),
        .data          (tx_data),
        .sda_in        (sda_in),
        .busy          (tx_busy),
        .done          (tx_done),
        .sda_drive_low (sda_drive_low),
        .scl_drive_low (scl_drive_low)
    );

    function [7:0] pcf_byte;
        input [3:0] nibble;
        input rs;
        input en;
        begin
            // Mapping PCF8574: {D7,D6,D5,D4, Backlight, E, RW, RS}
            pcf_byte = {nibble, 1'b1, en, 1'b0, rs};
        end
    endfunction

    // =========================================================
    // HÀM ROM ĐỘNG: TRỘN CHỮ TĨNH VỚI DỮ LIỆU SHT30
    // =========================================================
    function [8:0] lcd_rom;
        input [5:0] a;
        begin
            case (a)
                // LCD setup commands
                6'd0:  lcd_rom = {1'b0, 8'h28}; // 4-bit, 2 dòng, font 5x8
                6'd1:  lcd_rom = {1'b0, 8'h0C}; // display ON, cursor OFF
                6'd2:  lcd_rom = {1'b0, 8'h06}; // entry mode
                6'd3:  lcd_rom = {1'b0, 8'h01}; // clear display

                // Dòng 1: "Temp: XX.X C    "
                6'd4:  lcd_rom = {1'b0, 8'h80}; // Đưa con trỏ về đầu dòng 1
                6'd5:  lcd_rom = {1'b1, "T"}; 
                6'd6:  lcd_rom = {1'b1, "e"}; 
                6'd7:  lcd_rom = {1'b1, "m"}; 
                6'd8:  lcd_rom = {1'b1, "p"}; 
                6'd9:  lcd_rom = {1'b1, ":"}; 
                6'd10: lcd_rom = {1'b1, " "}; 
                // Xử lý toán học tách số (Mã ASCII của '0' là 8'h30)
                6'd11: lcd_rom = {1'b1, ((temp_val / 100) % 10) + 8'h30}; // Hàng chục
                6'd12: lcd_rom = {1'b1, ((temp_val / 10) % 10)  + 8'h30}; // Hàng đơn vị
                6'd13: lcd_rom = {1'b1, "."};                             // Dấu phẩy
                6'd14: lcd_rom = {1'b1, (temp_val % 10)         + 8'h30}; // Phần thập phân
                6'd15: lcd_rom = {1'b1, "C"}; 
                6'd16: lcd_rom = {1'b1, " "}; // Đệm khoảng trắng để lấp đầy 16 ký tự
                6'd17: lcd_rom = {1'b1, " "};
                6'd18: lcd_rom = {1'b1, " "};
                6'd19: lcd_rom = {1'b1, " "};
                6'd20: lcd_rom = {1'b1, " "};

                // Dòng 2: "Humi: XX.X %    "
                6'd21: lcd_rom = {1'b0, 8'hC0}; // Đưa con trỏ về đầu dòng 2
                6'd22: lcd_rom = {1'b1, "H"}; 
                6'd23: lcd_rom = {1'b1, "u"}; 
                6'd24: lcd_rom = {1'b1, "m"}; 
                6'd25: lcd_rom = {1'b1, "i"}; 
                6'd26: lcd_rom = {1'b1, ":"}; 
                6'd27: lcd_rom = {1'b1, " "}; 
                // Xử lý toán học tách số
                6'd28: lcd_rom = {1'b1, ((humi_val / 100) % 10) + 8'h30}; 
                6'd29: lcd_rom = {1'b1, ((humi_val / 10) % 10)  + 8'h30}; 
                6'd30: lcd_rom = {1'b1, "."}; 
                6'd31: lcd_rom = {1'b1, (humi_val % 10)         + 8'h30}; 
                6'd32: lcd_rom = {1'b1, " "};
                6'd33: lcd_rom = {1'b1, "%"}; 
                6'd34: lcd_rom = {1'b1, " "};
                6'd35: lcd_rom = {1'b1, " "};
                6'd36: lcd_rom = {1'b1, " "};
                6'd37: lcd_rom = {1'b1, " "};

                default: lcd_rom = {1'b1, " "};
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_POWER;
            ret_state <= RET_INIT;

            cnt <= 32'd0;
            post_delay <= 32'd0;

            init_step <= 3'd0;
            idx <= 6'd0;

            cur_byte <= 8'd0;
            cur_rs <= 1'b0;
            cur_nibble <= 4'd0;

            tx_start <= 1'b0;
            tx_data <= 8'd0;
        end else begin
            tx_start <= 1'b0;

            case (state)

                ST_POWER: begin
                    if (cnt < WAIT_POWER) begin
                        cnt <= cnt + 32'd1;
                    end else begin
                        cnt <= 32'd0;
                        init_step <= 3'd0;
                        state <= ST_INIT_LOAD;
                    end
                end

                ST_INIT_LOAD: begin
                    cur_rs <= 1'b0;
                    ret_state <= RET_INIT;

                    case (init_step)
                        3'd0: begin
                            cur_nibble <= 4'h3;
                            post_delay <= WAIT_5MS;
                            state <= ST_SEND_E1;
                        end
                        3'd1: begin
                            cur_nibble <= 4'h3;
                            post_delay <= WAIT_200US;
                            state <= ST_SEND_E1;
                        end
                        3'd2: begin
                            cur_nibble <= 4'h3;
                            post_delay <= WAIT_200US;
                            state <= ST_SEND_E1;
                        end
                        3'd3: begin
                            cur_nibble <= 4'h2;
                            post_delay <= WAIT_200US;
                            state <= ST_SEND_E1;
                        end
                        default: begin
                            idx <= 6'd0;
                            state <= ST_BYTE_LOAD;
                        end
                    endcase
                end

                ST_BYTE_LOAD: begin
                    if (idx < TOTAL_BYTES) begin
                        cur_rs <= rom_data[8];
                        cur_byte <= rom_data[7:0];
                        cur_nibble <= rom_data[7:4];

                        post_delay <= WAIT_50US;
                        ret_state <= RET_BYTE_LOW;

                        state <= ST_SEND_E1;
                    end else begin
                        state <= ST_DONE;
                    end
                end

                ST_SEND_E1: begin
                    if (!tx_busy) begin
                        tx_data <= pcf_byte(cur_nibble, cur_rs, 1'b1);
                        tx_start <= 1'b1;
                        state <= ST_WAIT_E1;
                    end
                end

                ST_WAIT_E1: begin
                    if (tx_done) state <= ST_SEND_E0;
                end

                ST_SEND_E0: begin
                    if (!tx_busy) begin
                        tx_data <= pcf_byte(cur_nibble, cur_rs, 1'b0);
                        tx_start <= 1'b1;
                        state <= ST_WAIT_E0;
                    end
                end

                ST_WAIT_E0: begin
                    if (tx_done) begin
                        cnt <= 32'd0;
                        state <= ST_AFTER_NIB;
                    end
                end

                ST_AFTER_NIB: begin
                    if (cnt < post_delay) begin
                        cnt <= cnt + 32'd1;
                    end else begin
                        cnt <= 32'd0;

                        case (ret_state)
                            RET_INIT: begin
                                init_step <= init_step + 3'd1;
                                state <= ST_INIT_LOAD;
                            end
                            RET_BYTE_LOW: begin
                                cur_nibble <= cur_byte[3:0];
                                if (cur_byte == 8'h01 || cur_byte == 8'h02)
                                    post_delay <= WAIT_2MS;
                                else
                                    post_delay <= WAIT_50US;

                                ret_state <= RET_BYTE_DONE;
                                state <= ST_SEND_E1;
                            end
                            RET_BYTE_DONE: begin
                                idx <= idx + 6'd1;
                                state <= ST_BYTE_LOAD;
                            end
                            default: state <= ST_DONE;
                        endcase
                    end
                end

                // TRẠNG THÁI MỚI: TỰ ĐỘNG REFRESH MÀN HÌNH
                ST_DONE: begin
                    if (cnt < WAIT_REFRESH) begin // Đợi 200ms
                        cnt <= cnt + 32'd1;
                    end else begin
                        cnt <= 32'd0;
                        idx <= 6'd4; // Quay về index số 4 (Lệnh ghi đè dòng 1, bỏ qua khởi tạo ban đầu)
                        state <= ST_BYTE_LOAD; // Bắt đầu load dữ liệu lại
                    end
                end

                default: state <= ST_POWER;
            endcase
        end
    end

endmodule


// =========================================================
// I2C Lõi gửi 1 Byte (Giữ nguyên gốc của bạn)
// =========================================================
module i2c_write_byte #(
    parameter integer DIVIDER = 250
)(
    input clk,
    input rst_n,

    input start,
    input [6:0] addr,
    input [7:0] data,

    input sda_in,

    output reg busy,
    output reg done,

    output reg sda_drive_low,
    output reg scl_drive_low
);

    localparam [3:0]
        S_IDLE      = 4'd0,
        S_START1    = 4'd1,
        S_START2    = 4'd2,
        S_START3    = 4'd3,
        S_BIT_SETUP = 4'd4,
        S_BIT_HIGH  = 4'd5,
        S_BIT_LOW   = 4'd6,
        S_ACK_SETUP = 4'd7,
        S_ACK_HIGH  = 4'd8,
        S_ACK_LOW   = 4'd9,
        S_STOP1     = 4'd10,
        S_STOP2     = 4'd11,
        S_STOP3     = 4'd12,
        S_DONE      = 4'd13;

    reg [3:0] state;
    reg [31:0] div_cnt;

    reg [15:0] shreg;
    reg [4:0] bit_pos;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            div_cnt <= 32'd0;
            shreg <= 16'd0;
            bit_pos <= 5'd0;
            busy <= 1'b0;
            done <= 1'b0;
            sda_drive_low <= 1'b0;
            scl_drive_low <= 1'b0;
        end else begin
            done <= 1'b0;

            if (state == S_IDLE) begin
                div_cnt <= 32'd0;
                sda_drive_low <= 1'b0;
                scl_drive_low <= 1'b0;
                busy <= 1'b0;

                if (start) begin
                    shreg <= {addr, 1'b0, data};
                    bit_pos <= 5'd15;
                    busy <= 1'b1;
                    state <= S_START1;
                end
            end else begin
                if (div_cnt < DIVIDER - 1) begin
                    div_cnt <= div_cnt + 32'd1;
                end else begin
                    div_cnt <= 32'd0;
                    case (state)
                        S_START1: begin
                            sda_drive_low <= 1'b0;
                            scl_drive_low <= 1'b0;
                            state <= S_START2;
                        end
                        S_START2: begin
                            sda_drive_low <= 1'b1;
                            scl_drive_low <= 1'b0;
                            state <= S_START3;
                        end
                        S_START3: begin
                            sda_drive_low <= 1'b1;
                            scl_drive_low <= 1'b1;
                            state <= S_BIT_SETUP;
                        end
                        S_BIT_SETUP: begin
                            scl_drive_low <= 1'b1;
                            if (shreg[bit_pos] == 1'b0) sda_drive_low <= 1'b1;
                            else                        sda_drive_low <= 1'b0;
                            state <= S_BIT_HIGH;
                        end
                        S_BIT_HIGH: begin
                            scl_drive_low <= 1'b0;
                            state <= S_BIT_LOW;
                        end
                        S_BIT_LOW: begin
                            scl_drive_low <= 1'b1;
                            if (bit_pos == 5'd8 || bit_pos == 5'd0) state <= S_ACK_SETUP;
                            else begin
                                bit_pos <= bit_pos - 5'd1;
                                state <= S_BIT_SETUP;
                            end
                        end
                        S_ACK_SETUP: begin
                            sda_drive_low <= 1'b0;
                            scl_drive_low <= 1'b1;
                            state <= S_ACK_HIGH;
                        end
                        S_ACK_HIGH: begin
                            scl_drive_low <= 1'b0;
                            state <= S_ACK_LOW;
                        end
                        S_ACK_LOW: begin
                            scl_drive_low <= 1'b1;
                            if (bit_pos == 5'd8) begin
                                bit_pos <= 5'd7;
                                state <= S_BIT_SETUP;
                            end else begin
                                state <= S_STOP1;
                            end
                        end
                        S_STOP1: begin
                            sda_drive_low <= 1'b1;
                            scl_drive_low <= 1'b1;
                            state <= S_STOP2;
                        end
                        S_STOP2: begin
                            sda_drive_low <= 1'b1;
                            scl_drive_low <= 1'b0;
                            state <= S_STOP3;
                        end
                        S_STOP3: begin
                            sda_drive_low <= 1'b0;
                            scl_drive_low <= 1'b0;
                            state <= S_DONE;
                        end
                        S_DONE: begin
                            busy <= 1'b0;
                            done <= 1'b1;
                            state <= S_IDLE;
                        end
                        default: state <= S_IDLE;
                    endcase
                end
            end
        end
    end
endmodule