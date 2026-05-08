`timescale 1ns / 1ps

module top_uart_ad9767_square (
    input  wire        clk_125m,
    input  wire        rst_btn,

    input  wire        uart_rx,
    output wire        uart_tx,

    output wire        led0,
    output reg         led1,
    output reg         led2,
    output wire        led3,

    output wire [13:0] dac_data,
    output wire        dac_clk,
    output wire        dac_wrt
);

    wire rst = rst_btn;

    // ============================================================
    // LED0: heartbeat
    // ============================================================
    reg [26:0] heartbeat_cnt = 27'd0;

    always @(posedge clk_125m) begin
        if (rst)
            heartbeat_cnt <= 27'd0;
        else
            heartbeat_cnt <= heartbeat_cnt + 1'b1;
    end

    assign led0 = heartbeat_cnt[26];

    // ============================================================
    // UART RX/TX echo path kept for later DAC/DDS control
    // ============================================================
    wire [7:0] rx_data;
    wire       rx_valid;

    uart_rx #(
        .CLK_FREQ(125_000_000),
        .BAUD_RATE(115200)
    ) u_uart_rx (
        .clk(clk_125m),
        .rst(rst),
        .rx(uart_rx),
        .data_out(rx_data),
        .data_valid(rx_valid)
    );

    reg  [7:0] tx_data  = 8'd0;
    reg        tx_start = 1'b0;
    wire       tx_busy;

    uart_tx #(
        .CLK_FREQ(125_000_000),
        .BAUD_RATE(115200)
    ) u_uart_tx (
        .clk(clk_125m),
        .rst(rst),
        .tx_start(tx_start),
        .data_in(tx_data),
        .tx(uart_tx),
        .tx_busy(tx_busy)
    );

    assign led3 = tx_busy;

    reg [7:0] pending_data  = 8'd0;
    reg       pending_valid = 1'b0;

    always @(posedge clk_125m) begin
        if (rst) begin
            tx_data       <= 8'd0;
            tx_start      <= 1'b0;
            pending_data  <= 8'd0;
            pending_valid <= 1'b0;
            led1          <= 1'b0;
            led2          <= 1'b0;
        end else begin
            tx_start <= 1'b0;

            if (rx_valid) begin
                pending_data  <= rx_data;
                pending_valid <= 1'b1;
                led1          <= ~led1;
            end

            if (pending_valid && !tx_busy && !tx_start) begin
                tx_data       <= pending_data;
                tx_start      <= 1'b1;
                pending_valid <= 1'b0;
                led2          <= ~led2;
            end
        end
    end

    // ============================================================
    // AD9767 P1/CH1 square-wave hardware test
    // ============================================================
    wire [13:0] dac_code;

    ad9767_square_1hz #(
        .CLK_FREQ_HZ(125_000_000),
        .HALF_PERIOD_CLKS(62_500_000),
        .LOW_CODE(14'd0),
        .HIGH_CODE(14'd16383)
    ) u_ad9767_square_1hz (
        .clk(clk_125m),
        .rst(rst),
        .dac_code(dac_code)
    );

    ad9767_parallel_if u_ad9767_parallel_if (
        .clk(clk_125m),
        .rst(rst),
        .sample_data(dac_code),
        .dac_data(dac_data),
        .dac_clk(dac_clk),
        .dac_wrt(dac_wrt)
    );

endmodule
