`timescale 1ns / 1ps

// ============================================================
// PYNQ-Z2 UART DDS + AD9767 — Logic-Analyzer Test
//
// Default: T-mode (bits in group toggle at 1KHz)
//   BTN0 press → switch between group-0 (bits 7:0) and
//                             group-1 (bits 13:8)
//
// UART: '0' staircase, '1' sine, '2' square,
//       'T' T-mode, 'L' low, 'M' mid, 'F' full,
//       'S'/'P' pause, 'G' resume
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
    output wire        dac_wrt,

    output wire [11:0] gpio_test
);

    // ============================================================
    // Power-on reset (holds rst ~2us after configuration)
    // ============================================================
    reg [7:0] por_cnt = 8'd0;
    wire por_rst = (por_cnt < 8'd255);

    always @(posedge clk_125m) begin
        if (por_cnt < 8'd255)
            por_cnt <= por_cnt + 1'b1;
    end

    // ============================================================
    // BTN0 synchronize + edge detect → group toggle
    // ============================================================
    // ============================================================
    // Heartbeat LED (~0.93 Hz)
    // ============================================================
    reg [26:0] heartbeat_cnt = 27'd0;

    always @(posedge clk_125m) begin
        if (por_rst)
            heartbeat_cnt <= 27'd0;
        else
            heartbeat_cnt <= heartbeat_cnt + 1'b1;
    end

    assign led0 = heartbeat_cnt[26];

    // ============================================================
    // UART RX
    // ============================================================
    wire [7:0] rx_data;
    wire       rx_valid;

    uart_rx #(
        .CLK_FREQ (125_000_000),
        .BAUD_RATE(115200)
    ) u_uart_rx (
        .clk        (clk_125m),
        .rst        (por_rst),
        .rx         (uart_rx),
        .data_out   (rx_data),
        .data_valid (rx_valid)
    );

    // ============================================================
    // UART TX
    // ============================================================
    wire [7:0] tx_data;
    wire       tx_start;
    wire       tx_busy;

    uart_tx #(
        .CLK_FREQ (125_000_000),
        .BAUD_RATE(115200)
    ) u_uart_tx (
        .clk      (clk_125m),
        .rst      (por_rst),
        .tx_start (tx_start),
        .data_in  (tx_data),
        .tx       (uart_tx),
        .tx_busy  (tx_busy)
    );

    assign led3 = tx_busy;

    // ============================================================
    // UART command parser
    // ============================================================
    wire [2:0] wave_sel;
    wire       dds_en;
    wire       pin_freq_mode = (wave_sel == 3'b111);

    uart_cmd u_uart_cmd (
        .clk      (clk_125m),
        .rst      (por_rst),
        .rx_data  (rx_data),
        .rx_valid (rx_valid),
        .tx_data  (tx_data),
        .tx_start (tx_start),
        .tx_busy  (tx_busy),
        .wave_sel (wave_sel),
        .dds_en   (dds_en)
    );

    // ============================================================
    // Activity LEDs
    // ============================================================
    reg led1_r = 1'b0;
    reg led2_r = 1'b0;

    always @(posedge clk_125m) begin
        if (por_rst) begin
            led1_r <= 1'b0;
            led2_r <= 1'b0;
        end else begin
            if (rx_valid) led1_r <= ~led1_r;
            if (tx_start) led2_r <= ~led2_r;
        end
    end

    assign led1 = led1_r;
    assign led2 = led2_r;

    // ============================================================
    // DDS core
    // ============================================================
    wire [13:0] dac_code;
    wire        sample_tick;

    // ============================================================
    // Multi-frequency pin test mode
    // dac_data[0..13] = 1kHz..14kHz
    // dac_clk/dac_wrt = 15kHz/16kHz
    // gpio_test[0..11] = 17kHz..28kHz
    // ============================================================
    localparam [31:0] PIN_TEST_BASE_FWORD = 32'd34360; // 1kHz at 125MHz

    reg [31:0] pin_freq_acc [0:27];
    integer pin_idx;

    always @(posedge clk_125m) begin
        if (por_rst) begin
            for (pin_idx = 0; pin_idx < 28; pin_idx = pin_idx + 1)
                pin_freq_acc[pin_idx] <= 32'd0;
        end else if (pin_freq_mode && dds_en) begin
            for (pin_idx = 0; pin_idx < 28; pin_idx = pin_idx + 1)
                pin_freq_acc[pin_idx] <= pin_freq_acc[pin_idx]
                                      + (PIN_TEST_BASE_FWORD * (pin_idx + 1));
        end
    end

    wire [13:0] pin_freq_dac_data = {
        pin_freq_acc[13][31],
        pin_freq_acc[12][31],
        pin_freq_acc[11][31],
        pin_freq_acc[10][31],
        pin_freq_acc[9][31],
        pin_freq_acc[8][31],
        pin_freq_acc[7][31],
        pin_freq_acc[6][31],
        pin_freq_acc[5][31],
        pin_freq_acc[4][31],
        pin_freq_acc[3][31],
        pin_freq_acc[2][31],
        pin_freq_acc[1][31],
        pin_freq_acc[0][31]
    };

    wire pin_freq_dac_clk = pin_freq_acc[14][31];
    wire pin_freq_dac_wrt = pin_freq_acc[15][31];

    wire [11:0] pin_freq_gpio = {
        pin_freq_acc[27][31],
        pin_freq_acc[26][31],
        pin_freq_acc[25][31],
        pin_freq_acc[24][31],
        pin_freq_acc[23][31],
        pin_freq_acc[22][31],
        pin_freq_acc[21][31],
        pin_freq_acc[20][31],
        pin_freq_acc[19][31],
        pin_freq_acc[18][31],
        pin_freq_acc[17][31],
        pin_freq_acc[16][31]
    };

    wire [13:0] ad9767_sample_data = pin_freq_mode ? pin_freq_dac_data : dac_code;

    dds_core #(
        .FWORD(32'd4294967)         // 1 KHz default at 1 MSPS
    ) u_dds_core (
        .clk      (clk_125m),
        .rst      (por_rst),
        .dds_en   (dds_en),
        .sample_tick(sample_tick),
        .wave_sel (wave_sel),
        .t_group  (1'b0),
        .dac_code (dac_code)
    );

    // ============================================================
    // AD9767 parallel interface
    // ============================================================
    ad9767_parallel_if #(
        .CLK_FREQ_HZ(125_000_000),
        .UPDATE_RATE_HZ(1_000_000),
        .DDS_LATENCY_CLKS(3),
        .DATA_SETUP_CLKS(2),
        .PULSE_HIGH_CLKS(2)
    ) u_ad9767_if (
        .clk         (clk_125m),
        .rst         (por_rst),
        .sample_data (ad9767_sample_data),
        .pin_freq_mode(pin_freq_mode),
        .pin_freq_dac_clk(pin_freq_dac_clk),
        .pin_freq_dac_wrt(pin_freq_dac_wrt),
        .dac_data    (dac_data),
        .dac_clk     (dac_clk),
        .dac_wrt     (dac_wrt),
        .sample_tick (sample_tick)
    );

    // Extra Raspberry Pi header GPIO pin test outputs.
    // In default T-mode, dac_code[0] is a 1 KHz square wave.
    assign gpio_test = pin_freq_mode ? pin_freq_gpio : {12{dac_code[0]}};

endmodule
