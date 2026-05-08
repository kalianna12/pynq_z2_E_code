`timescale 1ns / 1ps

// ============================================================
// UART Transmitter
// Format: 8N1
// idle = 1, start = 0, 8 data bits LSB first, stop = 1
// ============================================================
module uart_tx #(
    parameter CLK_FREQ  = 125_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       tx_start,
    input  wire [7:0] data_in,
    output reg        tx,
    output reg        tx_busy
);

    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    reg [15:0] clk_count = 16'd0;
    reg [3:0]  bit_index = 4'd0;
    reg [9:0]  tx_shift  = 10'b1111111111;

    always @(posedge clk) begin
        if (rst) begin
            tx        <= 1'b1;
            tx_busy   <= 1'b0;
            clk_count <= 16'd0;
            bit_index <= 4'd0;
            tx_shift  <= 10'b1111111111;
        end else begin
            if (!tx_busy) begin
                tx <= 1'b1;

                if (tx_start) begin
                    tx_shift  <= {1'b1, data_in, 1'b0};
                    tx_busy   <= 1'b1;
                    clk_count <= 16'd0;
                    bit_index <= 4'd0;
                end
            end else begin
                tx <= tx_shift[bit_index];

                if (clk_count == CLKS_PER_BIT - 1) begin
                    clk_count <= 16'd0;

                    if (bit_index == 4'd9) begin
                        tx_busy   <= 1'b0;
                        bit_index <= 4'd0;
                    end else begin
                        bit_index <= bit_index + 1'b1;
                    end
                end else begin
                    clk_count <= clk_count + 1'b1;
                end
            end
        end
    end

endmodule
