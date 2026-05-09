`timescale 1ns / 1ps

// UART command parser with multi-byte string response
// Commands:
//   '0' (0x30) → staircase wave
//   '1' (0x31) → sine wave
//   '2' (0x32) → square wave
//   'S' (0x53) → pause DDS
//   'G' (0x47) → resume DDS
// Response format: "<echo> <status>\r\n"
module uart_cmd (
    input  wire        clk,
    input  wire        rst,

    input  wire [7:0]  rx_data,
    input  wire        rx_valid,

    output reg  [7:0]  tx_data,
    output reg         tx_start,
    input  wire        tx_busy,

    output reg  [1:0]  wave_sel,
    output reg         dds_en
);

    // ---- FSM states ----
    localparam IDLE = 2'd0;
    localparam SEND = 2'd1;

    reg [1:0] state;

    // ---- command capture (never miss rx_valid) ----
    reg       cmd_ready;
    reg [7:0] cmd_byte;

    always @(posedge clk) begin
        if (rst) begin
            cmd_ready <= 1'b0;
            cmd_byte  <= 8'd0;
        end else begin
            if (rx_valid) begin
                cmd_ready <= 1'b1;
                cmd_byte  <= rx_data;
            end else if (state == IDLE && cmd_ready) begin
                cmd_ready <= 1'b0;
            end
        end
    end

    // ---- response buffer ----
    reg [7:0] resp_buf [0:9];   // max 10 bytes
    reg [3:0] resp_len;         // total bytes to send
    reg [3:0] resp_idx;         // current byte index

    always @(posedge clk) begin
        if (rst) begin
            wave_sel  <= 2'b00;
            dds_en    <= 1'b1;
            tx_data   <= 8'd0;
            tx_start  <= 1'b0;
            state     <= IDLE;
            resp_len  <= 4'd0;
            resp_idx  <= 4'd0;
        end else begin
            tx_start <= 1'b0;

            case (state)

                IDLE: begin
                    if (cmd_ready) begin
                        // decode command
                        case (cmd_byte)
                            8'h30: wave_sel <= 2'b00;   // '0' staircase
                            8'h31: wave_sel <= 2'b01;   // '1' sine
                            8'h32: wave_sel <= 2'b10;   // '2' square
                            8'h53: dds_en   <= 1'b0;    // 'S' pause
                            8'h47: dds_en   <= 1'b1;    // 'G' resume
                            default: ;
                        endcase

                        // fill response buffer
                        // fmt: "<cmd> <status>\r\n"
                        case (cmd_byte)
                            8'h30: begin
                                resp_buf[0] = 8'h30; resp_buf[1] = " ";
                                resp_buf[2] = "S";   resp_buf[3] = "T";
                                resp_buf[4] = "A";   resp_buf[5] = "I";
                                resp_buf[6] = "R";   resp_buf[7] = 8'h0D;
                                resp_buf[8] = 8'h0A;
                                resp_len <= 4'd9;
                            end
                            8'h31: begin
                                resp_buf[0] = 8'h31; resp_buf[1] = " ";
                                resp_buf[2] = "S";   resp_buf[3] = "I";
                                resp_buf[4] = "N";   resp_buf[5] = "E";
                                resp_buf[6] = 8'h0D; resp_buf[7] = 8'h0A;
                                resp_len <= 4'd8;
                            end
                            8'h32: begin
                                resp_buf[0] = 8'h32; resp_buf[1] = " ";
                                resp_buf[2] = "S";   resp_buf[3] = "Q";
                                resp_buf[4] = "U";   resp_buf[5] = "A";
                                resp_buf[6] = "R";   resp_buf[7] = "E";
                                resp_buf[8] = 8'h0D; resp_buf[9] = 8'h0A;
                                resp_len <= 4'd10;
                            end
                            8'h53: begin
                                resp_buf[0] = 8'h53; resp_buf[1] = " ";
                                resp_buf[2] = "P";   resp_buf[3] = "A";
                                resp_buf[4] = "U";   resp_buf[5] = "S";
                                resp_buf[6] = "E";   resp_buf[7] = 8'h0D;
                                resp_buf[8] = 8'h0A;
                                resp_len <= 4'd9;
                            end
                            8'h47: begin
                                resp_buf[0] = 8'h47; resp_buf[1] = " ";
                                resp_buf[2] = "R";   resp_buf[3] = "E";
                                resp_buf[4] = "S";   resp_buf[5] = "U";
                                resp_buf[6] = "M";   resp_buf[7] = "E";
                                resp_buf[8] = 8'h0D; resp_buf[9] = 8'h0A;
                                resp_len <= 4'd10;
                            end
                            default: begin
                                resp_buf[0] = "?"; resp_buf[1] = 8'h0D;
                                resp_buf[2] = 8'h0A;
                                resp_len <= 4'd3;
                            end
                        endcase

                        resp_idx <= 4'd0;
                        state    <= SEND;
                    end
                end

                SEND: begin
                    if (!tx_busy && !tx_start) begin
                        tx_data  <= resp_buf[resp_idx];
                        tx_start <= 1'b1;

                        if (resp_idx == resp_len - 1) begin
                            resp_idx <= 4'd0;
                            state    <= IDLE;
                        end else begin
                            resp_idx <= resp_idx + 1'b1;
                        end
                    end
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule
