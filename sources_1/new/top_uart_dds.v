`timescale 1ns / 1ps

// ============================================================
// PYNQ-Z2 UART DDS + AD9767 - Logic-Analyzer Test
//
// Default: T-mode (bits in group toggle at 1KHz)
//   BTN0 press ¡ú switch between group-0 (bits 7:0) and
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

    output wire        ad7606_reset,
    output wire        ad7606_convst_a,
    output wire        ad7606_convst_b,
    output wire        ad7606_cs_n,
    output wire        ad7606_sclk,
    input  wire        ad7606_douta,
    input  wire        ad7606_busy
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
    // BTN0 synchronize + edge detect ¡ú group toggle
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
    wire       adc_start;
    wire       adc_busy;
    wire       adc_done;
    wire signed [15:0] adc_vin_max;
    wire signed [15:0] adc_vin_min;
    wire signed [15:0] adc_vout_max;
    wire signed [15:0] adc_vout_min;
    wire [16:0] adc_vin_pp;
    wire [16:0] adc_vout_pp;

    uart_cmd u_uart_cmd (
        .clk      (clk_125m),
        .rst      (por_rst),
        .rx_data  (rx_data),
        .rx_valid (rx_valid),
        .tx_data  (tx_data),
        .tx_start (tx_start),
        .tx_busy  (tx_busy),
        .wave_sel (wave_sel),
        .dds_en   (dds_en),
        .adc_start(adc_start),
        .adc_busy (adc_busy),
        .adc_done (adc_done),
        .adc_vin_max(adc_vin_max),
        .adc_vin_min(adc_vin_min),
        .adc_vout_max(adc_vout_max),
        .adc_vout_min(adc_vout_min),
        .adc_vin_pp(adc_vin_pp),
        .adc_vout_pp(adc_vout_pp)
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

    wire [13:0] ad9767_sample_data = pin_freq_mode ? pin_freq_dac_data : dac_code;

    dds_core #(
        .FWORD(32'd171799),         // 1 KHz default at 25 MSPS
        .SWEEP_FWORD_MIN(32'd171799),
        .SWEEP_FWORD_MAX(32'd17179869),
        .SWEEP_FWORD_STEP(32'd171799),
        .SWEEP_HOLD_TICKS(32'd2500000)
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
        .UPDATE_RATE_HZ(25_000_000),
        .DDS_LATENCY_CLKS(3),
        .DATA_SETUP_CLKS(2),
        .PULSE_HIGH_CLKS(2)
    ) u_ad9767_if (
        .clk         (clk_125m),
        .rst         (por_rst),
        .sample_data (ad9767_sample_data),
        .dac_data    (dac_data),
        .dac_clk     (dac_clk),
        .dac_wrt     (dac_wrt),
        .sample_tick (sample_tick)
    );

    // ============================================================
    // AD7606 serial reader
    // ============================================================
    ad7606_serial_reader #(
        .CLK_FREQ_HZ(125_000_000),
        .SCLK_DIV(25),
        .SAMPLE_COUNT(256)
    ) u_ad7606_reader (
        .clk(clk_125m),
        .rst(por_rst),
        .start(adc_start),
        .ad7606_reset(ad7606_reset),
        .ad7606_convst_a(ad7606_convst_a),
        .ad7606_convst_b(ad7606_convst_b),
        .ad7606_cs_n(ad7606_cs_n),
        .ad7606_sclk(ad7606_sclk),
        .ad7606_douta(ad7606_douta),
        .ad7606_busy(ad7606_busy),
        .busy(adc_busy),
        .done(adc_done),
        .vin_max(adc_vin_max),
        .vin_min(adc_vin_min),
        .vout_max(adc_vout_max),
        .vout_min(adc_vout_min),
        .vin_pp(adc_vin_pp),
        .vout_pp(adc_vout_pp)
    );

endmodule
