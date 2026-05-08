`timescale 1ns / 1ps

module ad9767_parallel_if (
    input  wire        clk,
    input  wire        rst,
    input  wire [13:0] sample_data,

    output reg  [13:0] dac_data,
    output wire        dac_clk,
    output wire        dac_wrt
);

    always @(posedge clk) begin
        if (rst)
            dac_data <= 14'd0;
        else
            dac_data <= sample_data;
    end

    // Forward the 125 MHz PL clock with output DDR registers.
    // AD9767 P1 CLK1 and WRT1 are driven in phase for this first hardware test.
    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) u_oddr_dac_clk (
        .Q(dac_clk),
        .C(clk),
        .CE(1'b1),
        .D1(1'b1),
        .D2(1'b0),
        .R(rst),
        .S(1'b0)
    );

    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) u_oddr_dac_wrt (
        .Q(dac_wrt),
        .C(clk),
        .CE(1'b1),
        .D1(1'b1),
        .D2(1'b0),
        .R(rst),
        .S(1'b0)
    );

endmodule
