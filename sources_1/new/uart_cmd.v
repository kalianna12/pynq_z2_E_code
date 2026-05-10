`timescale 1ns / 1ps

module uart_cmd (
    input  wire        clk,
    input  wire        rst,

    input  wire [7:0]  rx_data,
    input  wire        rx_valid,

    output reg  [7:0]  tx_data,
    output reg         tx_start,
    input  wire        tx_busy,

    output reg  [2:0]  wave_sel,
    output reg         dds_en,

    output reg         adc_start,
    input  wire        adc_busy,
    input  wire        adc_done,
    input  wire signed [15:0] adc_vin_max,
    input  wire signed [15:0] adc_vin_min,
    input  wire signed [15:0] adc_vout_max,
    input  wire signed [15:0] adc_vout_min,
    input  wire [16:0] adc_vin_pp,
    input  wire [16:0] adc_vout_pp
);

    localparam IDLE     = 3'd0;
    localparam WAIT_ADC = 3'd1;
    localparam SEND     = 3'd2;

    reg [2:0] state;

    reg       cmd_pending;
    reg [7:0] cmd_latched;

    reg [7:0] resp_buf [0:159];
    reg [7:0] resp_len;
    reg [7:0] resp_idx;

    task append_char;
        input [7:0] ch;
        begin
            resp_buf[resp_len] = ch;
            resp_len = resp_len + 1'b1;
        end
    endtask

    function [7:0] hex_char;
        input [3:0] nibble;
        begin
            if (nibble < 4'd10)
                hex_char = "0" + nibble;
            else
                hex_char = "A" + (nibble - 4'd10);
        end
    endfunction

    task append_hex16;
        input [15:0] value;
        begin
            append_char(hex_char(value[15:12]));
            append_char(hex_char(value[11:8]));
            append_char(hex_char(value[7:4]));
            append_char(hex_char(value[3:0]));
        end
    endtask

    task append_hex17;
        input [16:0] value;
        begin
            append_char(hex_char({3'b000, value[16]}));
            append_char(hex_char(value[15:12]));
            append_char(hex_char(value[11:8]));
            append_char(hex_char(value[7:4]));
            append_char(hex_char(value[3:0]));
        end
    endtask

    task append_f1000;
        begin
            append_char("F"); append_char("="); append_char("1"); append_char("0");
            append_char("0"); append_char("0"); append_char(",");
        end
    endtask

    task append_name_vin_max;
        begin
            append_char("V"); append_char("I"); append_char("N"); append_char("_");
            append_char("M"); append_char("A"); append_char("X"); append_char("=");
        end
    endtask

    task append_name_vin_min;
        begin
            append_char("V"); append_char("I"); append_char("N"); append_char("_");
            append_char("M"); append_char("I"); append_char("N"); append_char("=");
        end
    endtask

    task append_name_vout_max;
        begin
            append_char("V"); append_char("O"); append_char("U"); append_char("T"); append_char("_");
            append_char("M"); append_char("A"); append_char("X"); append_char("=");
        end
    endtask

    task append_name_vout_min;
        begin
            append_char("V"); append_char("O"); append_char("U"); append_char("T"); append_char("_");
            append_char("M"); append_char("I"); append_char("N"); append_char("=");
        end
    endtask

    task append_name_vin_pp;
        begin
            append_char("V"); append_char("I"); append_char("N"); append_char("_");
            append_char("P"); append_char("P"); append_char("=");
        end
    endtask

    task append_name_vout_pp;
        begin
            append_char("V"); append_char("O"); append_char("U"); append_char("T"); append_char("_");
            append_char("P"); append_char("P"); append_char("=");
        end
    endtask

    task build_adc_response;
        begin
            resp_len = 8'd0;
            append_f1000();
            append_name_vin_max();  append_hex16(adc_vin_max);  append_char(",");
            append_name_vin_min();  append_hex16(adc_vin_min);  append_char(",");
            append_name_vout_max(); append_hex16(adc_vout_max); append_char(",");
            append_name_vout_min(); append_hex16(adc_vout_min); append_char(",");
            append_name_vin_pp();   append_hex17(adc_vin_pp);   append_char(",");
            append_name_vout_pp();  append_hex17(adc_vout_pp);
            append_char(8'h0D);
            append_char(8'h0A);
        end
    endtask

    task build_short_response;
        input [7:0] c0;
        input [7:0] c1;
        input [7:0] c2;
        input [7:0] c3;
        input [7:0] c4;
        input [7:0] n;
        integer i;
        begin
            resp_len = 8'd0;
            if (n > 0) append_char(c0);
            if (n > 1) append_char(c1);
            if (n > 2) append_char(c2);
            if (n > 3) append_char(c3);
            if (n > 4) append_char(c4);
            append_char(8'h0D);
            append_char(8'h0A);
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            state       <= IDLE;
            wave_sel    <= 3'b011;
            dds_en      <= 1'b1;
            tx_data     <= 8'd0;
            tx_start    <= 1'b0;
            adc_start   <= 1'b0;
            cmd_pending <= 1'b0;
            cmd_latched <= 8'd0;
            resp_len    <= 8'd0;
            resp_idx    <= 8'd0;
        end else begin
            tx_start  <= 1'b0;
            adc_start <= 1'b0;

            case (state)
                IDLE: begin
                    if (cmd_pending) begin
                        cmd_pending <= 1'b0;

                        if (cmd_latched == 8'h0D || cmd_latched == 8'h0A) begin
                            state <= IDLE;
                        end else begin
                            case (cmd_latched)
                                8'h30: begin wave_sel <= 3'b000; build_short_response("0"," ","S","T","A",5); state <= SEND; end
                                8'h31: begin wave_sel <= 3'b001; build_short_response("1"," ","S","I","N",5); state <= SEND; end
                                8'h32: begin wave_sel <= 3'b010; build_short_response("2"," ","S","Q","U",5); state <= SEND; end
                                8'h4D, 8'h6D: begin wave_sel <= 3'b111; dds_en <= 1'b1; build_short_response("M","U","L","T","I",5); state <= SEND; end
                                8'h57, 8'h77: begin wave_sel <= 3'b100; dds_en <= 1'b1; build_short_response("S","W","E","E","P",5); state <= SEND; end
                                8'h53, 8'h73: begin dds_en <= 1'b0; build_short_response("P","A","U","S","E",5); state <= SEND; end
                                8'h47, 8'h67: begin dds_en <= 1'b1; build_short_response("R","E","S","U","M",5); state <= SEND; end
                                8'h41, 8'h61: begin
                                    if (!adc_busy) begin
                                        adc_start <= 1'b1;
                                        state <= WAIT_ADC;
                                    end else begin
                                        build_short_response("B","U","S","Y"," ",4);
                                        state <= SEND;
                                    end
                                end
                                default: begin build_short_response("?"," "," "," "," ",1); state <= SEND; end
                            endcase

                            resp_idx <= 8'd0;
                        end
                    end
                end

                WAIT_ADC: begin
                    if (adc_done) begin
                        build_adc_response();
                        resp_idx <= 8'd0;
                        state <= SEND;
                    end
                end

                SEND: begin
                    if (!tx_busy && !tx_start) begin
                        tx_data  <= resp_buf[resp_idx];
                        tx_start <= 1'b1;

                        if (resp_idx == resp_len - 1) begin
                            resp_idx <= 8'd0;
                            state    <= IDLE;
                        end else begin
                            resp_idx <= resp_idx + 1'b1;
                        end
                    end
                end

                default: state <= IDLE;
            endcase

            if (rx_valid) begin
                cmd_pending <= 1'b1;
                cmd_latched <= rx_data;
            end
        end
    end

endmodule
