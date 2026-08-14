module Top_Module_Cordic (
    input wire iClk,
    input wire iReset_n,
    // Avalon-MM slave for mode control
    input wire iChip_select_n,
    input wire iWrite_n,
    input wire iRead_n,
    input wire [3:0] iAddress,
    input wire [31:0] iWrite_data,
    output wire [31:0] oRead_data,

    // SGDMA stream input: x, y, z as 3 successive 32-bit words
    input wire [31:0] i_sink_data,
    input wire i_sink_valid,
    input wire i_sink_startofpacket,
    input wire i_sink_endofpacket,
    output wire o_sink_ready,

    // SGDMA stream output: x, y, z as 3 successive 32-bit words
    output wire [31:0] o_source_data,
    output wire o_source_valid,
    output wire o_source_startofpacket,
    output wire o_source_endofpacket,
    input wire i_source_ready

);

    wire signed [31:0] dp_x_out, dp_y_out, dp_z_out;
    wire done_stage_19;

    wire ctrl_start_pulse;
    wire ctrl_mode;
    wire ctrl_irq_en;
    wire signed [31:0] ctrl_x_in, ctrl_y_in, ctrl_z_in;
    wire [31:0] ctrl_read_data;
    wire ctrl_irq;

    reg signed [31:0] dp_x_in, dp_y_in, dp_z_in;
    reg dp_start;

    reg signed [31:0] stream_x_in, stream_y_in, stream_z_in;
    reg [1:0] stream_word_count;
    reg stream_start_req;

    reg signed [31:0] source_x, source_y, source_z;
    reg [1:0] source_word_count;
    reg source_pending;

    reg processing;

    wire sink_accept = i_sink_valid && o_sink_ready;
    wire source_accept = o_source_valid && i_source_ready;
    wire busy = processing || source_pending || stream_start_req || dp_start || ctrl_start_pulse;

    assign o_sink_ready = ~processing && ~source_pending && ~stream_start_req && ~ctrl_start_pulse;
    assign o_source_valid = source_pending;
    assign o_source_data = (source_word_count == 2'd0) ? source_x :
                           (source_word_count == 2'd1) ? source_y :
                                                        source_z;
    assign o_source_startofpacket = (source_word_count == 2'd0);
    assign o_source_endofpacket = (source_word_count == 2'd2);
    assign oRead_data = ctrl_read_data;

    control_slave_cordic control_slave (
        .iClk(iClk),
        .iReset_n(iReset_n),
        .iChip_select_n(iChip_select_n),
        .iWrite_n(iWrite_n),
        .iRead_n(iRead_n),
        .iAddress(iAddress),
        .iWrite_data(iWrite_data),
        .oRead_data(ctrl_read_data),
        .oStart(ctrl_start_pulse),
        .oMode(ctrl_mode),
        .oIrq_en(ctrl_irq_en),
        .oX_in(ctrl_x_in),
        .oY_in(ctrl_y_in),
        .oZ_in(ctrl_z_in),
        .iBusy(busy),
        .iDone(done_stage_19),
        .iX_out(dp_x_out),
        .iY_out(dp_y_out),
        .iZ_out(dp_z_out),
        .oIrq(ctrl_irq)
    );

    Cordic_Datapath datapath (
        .clk(iClk),
        .rst(~iReset_n),
        .load_en_in(dp_start),
        .enable_output(1'b1),
        .mode(ctrl_mode),
        .data_in_x(dp_x_in),
        .data_in_y(dp_y_in),
        .data_in_z(dp_z_in),
        .data_out_x(dp_x_out),
        .data_out_y(dp_y_out),
        .data_out_z(dp_z_out),
        .done_stage_19(done_stage_19)
    );

    always @(posedge iClk or negedge iReset_n) begin
        if (~iReset_n) begin
            dp_x_in <= 32'sd0;
            dp_y_in <= 32'sd0;
            dp_z_in <= 32'sd0;
            dp_start <= 1'b0;

            stream_x_in <= 32'sd0;
            stream_y_in <= 32'sd0;
            stream_z_in <= 32'sd0;
            stream_word_count <= 2'd0;
            stream_start_req <= 1'b0;

            source_x <= 32'sd0;
            source_y <= 32'sd0;
            source_z <= 32'sd0;
            source_word_count <= 2'd0;
            source_pending <= 1'b0;

            processing <= 1'b0;
        end else begin
            dp_start <= 1'b0;

            if (sink_accept) begin
                if (i_sink_startofpacket) begin
                    stream_word_count <= 2'd0;
                end

                case (stream_word_count)
                    2'd0: stream_x_in <= i_sink_data;
                    2'd1: stream_y_in <= i_sink_data;
                    2'd2: begin
                        stream_z_in <= i_sink_data;
                        stream_start_req <= 1'b1;
                    end
                    default: begin
                        stream_x_in <= stream_x_in;
                        stream_y_in <= stream_y_in;
                        stream_z_in <= stream_z_in;
                    end
                endcase

                if (stream_word_count == 2'd2) begin
                    stream_word_count <= 2'd0;
                end else begin
                    stream_word_count <= stream_word_count + 2'd1;
                end

                if (i_sink_endofpacket) begin
                    stream_start_req <= 1'b1;
                end
            end

            if (ctrl_start_pulse && !processing && !source_pending) begin
                dp_x_in <= ctrl_x_in;
                dp_y_in <= ctrl_y_in;
                dp_z_in <= ctrl_z_in;
                dp_start <= 1'b1;
                processing <= 1'b1;
                stream_start_req <= 1'b0;
                stream_word_count <= 2'd0;
            end else if (stream_start_req && !processing && !source_pending) begin
                dp_x_in <= stream_x_in;
                dp_y_in <= stream_y_in;
                dp_z_in <= stream_z_in;
                dp_start <= 1'b1;
                processing <= 1'b1;
                stream_start_req <= 1'b0;
            end

            if (done_stage_19) begin
                source_x <= dp_x_out;
                source_y <= dp_y_out;
                source_z <= dp_z_out;
                source_word_count <= 2'd0;
                source_pending <= 1'b1;
                processing <= 1'b0;
            end

            if (source_accept) begin
                if (source_word_count == 2'd2) begin
                    source_pending <= 1'b0;
                end else begin
                    source_word_count <= source_word_count + 2'd1;
                end
            end
        end
    end


endmodule
