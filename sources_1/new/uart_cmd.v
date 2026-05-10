`timescale 1ns / 1ps

// UART command parser with string response
//   '0' (0x30) → staircase    '1' (0x31) → sine    '2' (0x32) → square
//   'T' 't'    → T-mode       'L' 'l'    → fixed low
//   'M' 'm'    → mid-scale    'F' 'f'    → full-scale
//   'S' 's' 'P' 'p' → pause   'G' 'g'    → resume
//   CR (0x0D) / LF (0x0A) → silently ignored
//
// Default on reset: T-mode (wave_sel = 3'b011)
module uart_cmd (
    input  wire        clk,
    input  wire        rst,

    input  wire [7:0]  rx_data,
    input  wire        rx_valid,

    output reg  [7:0]  tx_data,
    output reg         tx_start,
    input  wire        tx_busy,

    output reg  [2:0]  wave_sel,
    output reg         dds_en
);

    localparam IDLE = 2'd0;
    localparam SEND = 2'd1;

    reg [1:0] state;

    // command capture (never miss rx_valid)
    reg       cmd_pending;
    reg [7:0] cmd_latched;

    // response buffer: max 24 bytes
    reg [7:0] resp_buf [0:23];
    reg [4:0] resp_len;
    reg [4:0] resp_idx;

    always @(posedge clk) begin
        if (rst) begin
            state       <= IDLE;
            wave_sel    <= 3'b011;    // default T-mode
            dds_en      <= 1'b1;
            tx_data     <= 8'd0;
            tx_start    <= 1'b0;
            cmd_pending <= 1'b0;
            cmd_latched <= 8'd0;
            resp_len    <= 5'd0;
            resp_idx    <= 5'd0;
        end else begin
            tx_start <= 1'b0;

            case (state)

                IDLE: begin
                    if (cmd_pending) begin
                        cmd_pending <= 1'b0;

                        // skip CR / LF silently
                        if (cmd_latched == 8'h0D || cmd_latched == 8'h0A) begin
                            state <= IDLE;
                        end
                        else begin

                            case (cmd_latched)
                                8'h30: wave_sel <= 3'b000;  // '0' staircase
                                8'h31: wave_sel <= 3'b001;  // '1' sine
                                8'h32: wave_sel <= 3'b010;  // '2' square
                                8'h4D, 8'h6D: begin             // 'M','m' multi-frequency pin test
                                    wave_sel <= 3'b111;
                                    dds_en   <= 1'b1;
                                end
                                8'h57, 8'h77: begin             // 'W','w' sine sweep
                                    wave_sel <= 3'b100;
                                    dds_en   <= 1'b1;
                                end
                                8'h53, 8'h73: dds_en <= 1'b0;   // 'S','s' pause
                                8'h47, 8'h67: dds_en <= 1'b1;   // 'G','g' resume
                                default: ;
                            endcase

                            case (cmd_latched)
                                8'h30: begin
                                    resp_buf[0]="0"; resp_buf[1]=" ";
                                    resp_buf[2]="S"; resp_buf[3]="T";
                                    resp_buf[4]="A"; resp_buf[5]="I";
                                    resp_buf[6]="R"; resp_buf[7]=8'h0D;
                                    resp_buf[8]=8'h0A; resp_len=5'd9;
                                end
                                8'h31: begin
                                    resp_buf[0]="1"; resp_buf[1]=" ";
                                    resp_buf[2]="S"; resp_buf[3]="I";
                                    resp_buf[4]="N"; resp_buf[5]="E";
                                    resp_buf[6]=8'h0D; resp_buf[7]=8'h0A;
                                    resp_len=5'd8;
                                end
                                8'h32: begin
                                    resp_buf[0]="2"; resp_buf[1]=" ";
                                    resp_buf[2]="S"; resp_buf[3]="Q";
                                    resp_buf[4]="U"; resp_buf[5]="A";
                                    resp_buf[6]="R"; resp_buf[7]="E";
                                    resp_buf[8]=8'h0D; resp_buf[9]=8'h0A;
                                    resp_len=5'd10;
                                end
                                8'h4D, 8'h6D: begin
                                    resp_buf[0]=cmd_latched; resp_buf[1]=" ";
                                    resp_buf[2]="M"; resp_buf[3]="U";
                                    resp_buf[4]="L"; resp_buf[5]="T";
                                    resp_buf[6]="I"; resp_buf[7]=8'h0D;
                                    resp_buf[8]=8'h0A; resp_len=5'd9;
                                end
                                8'h57, 8'h77: begin
                                    resp_buf[0]=cmd_latched; resp_buf[1]=" ";
                                    resp_buf[2]="S"; resp_buf[3]="W";
                                    resp_buf[4]="E"; resp_buf[5]="E";
                                    resp_buf[6]="P"; resp_buf[7]=8'h0D;
                                    resp_buf[8]=8'h0A; resp_len=5'd9;
                                end
                                8'h53, 8'h73: begin
                                    resp_buf[0]=cmd_latched; resp_buf[1]=" ";
                                    resp_buf[2]="P"; resp_buf[3]="A";
                                    resp_buf[4]="U"; resp_buf[5]="S";
                                    resp_buf[6]="E"; resp_buf[7]=8'h0D;
                                    resp_buf[8]=8'h0A; resp_len=5'd9;
                                end
                                8'h47, 8'h67: begin
                                    resp_buf[0]=cmd_latched; resp_buf[1]=" ";
                                    resp_buf[2]="R"; resp_buf[3]="E";
                                    resp_buf[4]="S"; resp_buf[5]="U";
                                    resp_buf[6]="M"; resp_buf[7]="E";
                                    resp_buf[8]=8'h0D; resp_buf[9]=8'h0A;
                                    resp_len=5'd10;
                                end
                                default: begin
                                    resp_buf[0]="?"; resp_buf[1]=8'h0D;
                                    resp_buf[2]=8'h0A; resp_len=5'd3;
                                end
                            endcase

                            resp_idx <= 5'd0;
                            state    <= SEND;
                        end
                    end
                end

                SEND: begin
                    if (!tx_busy && !tx_start) begin
                        tx_data  <= resp_buf[resp_idx];
                        tx_start <= 1'b1;

                        if (resp_idx == resp_len - 1) begin
                            resp_idx <= 5'd0;
                            state    <= IDLE;
                        end else begin
                            resp_idx <= resp_idx + 1'b1;
                        end
                    end
                end

                default: state <= IDLE;

            endcase

            // rx_valid capture LAST — wins over cmd_pending clear above
            if (rx_valid) begin
                cmd_pending <= 1'b1;
                cmd_latched <= rx_data;
            end
        end
    end

endmodule
