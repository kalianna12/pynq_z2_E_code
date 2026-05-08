`timescale 1ns / 1ps

module ad9767_square_1hz #(
    parameter integer CLK_FREQ_HZ      = 125_000_000,
    parameter integer HALF_PERIOD_CLKS = 62_500_000,
    parameter [13:0]  LOW_CODE         = 14'd0,
    parameter [13:0]  HIGH_CODE        = 14'd16383
)(
    input  wire        clk,
    input  wire        rst,
    output reg  [13:0] dac_code
);

    reg [31:0] half_period_cnt = 32'd0;
    reg        square_state    = 1'b0;

    always @(posedge clk) begin
        if (rst) begin
            half_period_cnt <= 32'd0;
            square_state    <= 1'b0;
            dac_code        <= LOW_CODE;
        end else begin
            if (half_period_cnt == HALF_PERIOD_CLKS - 1) begin
                half_period_cnt <= 32'd0;
                square_state    <= ~square_state;
                dac_code        <= square_state ? LOW_CODE : HIGH_CODE;
            end else begin
                half_period_cnt <= half_period_cnt + 1'b1;
            end
        end
    end

endmodule
