`timescale 1ns / 1ps

// UART command parser
// Single-byte commands, echoes back received byte as ACK
//   '0' (0x30) → staircase wave
//   '1' (0x31) → sine wave
//   '2' (0x32) → square wave
//   'S' (0x53) → pause DDS
//   'G' (0x47) → resume DDS
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

    reg [7:0] pending_data;
    reg       pending_valid;

    always @(posedge clk) begin
        if (rst) begin
            wave_sel      <= 2'b00;
            dds_en        <= 1'b1;
            tx_data       <= 8'd0;
            tx_start      <= 1'b0;
            pending_data  <= 8'd0;
            pending_valid <= 1'b0;
        end else begin
            tx_start <= 1'b0;

            if (rx_valid) begin
                pending_data  <= rx_data;
                pending_valid <= 1'b1;

                case (rx_data)
                    8'h30: wave_sel <= 2'b00;   // '0'
                    8'h31: wave_sel <= 2'b01;   // '1'
                    8'h32: wave_sel <= 2'b10;   // '2'
                    8'h53: dds_en   <= 1'b0;    // 'S'
                    8'h47: dds_en   <= 1'b1;    // 'G'
                    default: ;                     // ignore
                endcase
            end

            if (pending_valid && !tx_busy && !tx_start) begin
                tx_data       <= pending_data;
                tx_start      <= 1'b1;
                pending_valid <= 1'b0;
            end
        end
    end

endmodule
