`timescale 1ns / 1ps

// ============================================================
// PYNQ-Z2 UART DDS + AD9767
// UART commands: '0' staircase, '1' sine, '2' square
//                 'S' pause,   'G' resume
// ============================================================
module top_uart_dds (
    input  wire        clk_125m,
    input  wire        rst_btn,

    input  wire        uart_rx,
    output wire        uart_tx,

    output wire        led0,
    output wire        led1,
    output wire        led2,
    output wire        led3,

    output wire [13:0] dac_data,
    output wire        dac_clk,
    output wire        dac_wrt
);

    wire rst = rst_btn;

    // ---- heartbeat LED ----
    reg [26:0] heartbeat_cnt = 27'd0;

    always @(posedge clk_125m) begin
        if (rst)
            heartbeat_cnt <= 27'd0;
        else
            heartbeat_cnt <= heartbeat_cnt + 1'b1;
    end

    assign led0 = heartbeat_cnt[26];

    // ---- UART RX ----
    wire [7:0] rx_data;
    wire       rx_valid;

    uart_rx #(
        .CLK_FREQ (125_000_000),
        .BAUD_RATE(115200)
    ) u_uart_rx (
        .clk        (clk_125m),
        .rst        (rst),
        .rx         (uart_rx),
        .data_out   (rx_data),
        .data_valid (rx_valid)
    );

    // ---- UART TX ----
    wire [7:0] tx_data;
    wire       tx_start;
    wire       tx_busy;

    uart_tx #(
        .CLK_FREQ (125_000_000),
        .BAUD_RATE(115200)
    ) u_uart_tx (
        .clk      (clk_125m),
        .rst      (rst),
        .tx_start (tx_start),
        .data_in  (tx_data),
        .tx       (uart_tx),
        .tx_busy  (tx_busy)
    );

    assign led3 = tx_busy;

    // ---- UART command parser ----
    wire [1:0] wave_sel;
    wire       dds_en;

    uart_cmd u_uart_cmd (
        .clk      (clk_125m),
        .rst      (rst),
        .rx_data  (rx_data),
        .rx_valid (rx_valid),
        .tx_data  (tx_data),
        .tx_start (tx_start),
        .tx_busy  (tx_busy),
        .wave_sel (wave_sel),
        .dds_en   (dds_en)
    );

    // ---- activity LEDs ----
    reg led1_r = 1'b0;
    reg led2_r = 1'b0;

    always @(posedge clk_125m) begin
        if (rst) begin
            led1_r <= 1'b0;
            led2_r <= 1'b0;
        end else begin
            if (rx_valid) led1_r <= ~led1_r;
            if (tx_start) led2_r <= ~led2_r;
        end
    end

    assign led1 = led1_r;
    assign led2 = led2_r;

    // ---- DDS core ----
    wire [13:0] dac_code;

    dds_core #(
        .FWORD(32'd34360)   // 1 KHz default
    ) u_dds_core (
        .clk      (clk_125m),
        .rst      (rst),
        .dds_en   (dds_en),
        .wave_sel (wave_sel),
        .dac_code (dac_code)
    );

    // ---- AD9767 parallel interface ----
    ad9767_parallel_if u_ad9767_if (
        .clk         (clk_125m),
        .rst         (rst),
        .sample_data (dac_code),
        .dac_data    (dac_data),
        .dac_clk     (dac_clk),
        .dac_wrt     (dac_wrt)
    );

endmodule
