`timescale 1ns / 1ps

module led_test (
    input  wire clk_125m,
    input  wire rst_btn,

    input  wire uart_rx,
    output wire uart_tx,

    output wire led0,
    output reg  led1,
    output reg  led2,
    output wire led3
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
    // UART RX
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

    // ============================================================
    // UART TX
    // ============================================================
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

    // ============================================================
    // Echo logic
    // Receive byte, send it back
    // ============================================================
    reg [7:0] pending_data = 8'd0;
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

            // 收到一个字节
            if (rx_valid) begin
                pending_data  <= rx_data;
                pending_valid <= 1'b1;
                led1 <= ~led1;       // LED1 每收到一个字节翻转
            end

            // 发送一个字节
            if (pending_valid && !tx_busy && !tx_start) begin
                tx_data       <= pending_data;
                tx_start      <= 1'b1;
                pending_valid <= 1'b0;
                led2 <= ~led2;       // LED2 每发送一个字节翻转
            end
        end
    end

endmodule


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


// ============================================================
// UART Receiver
// Format: 8N1
// idle = 1, start = 0, 8 data bits LSB first, stop = 1
// ============================================================
module uart_rx #(
    parameter CLK_FREQ  = 125_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       rx,
    output reg [7:0]  data_out,
    output reg        data_valid
);

    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam integer HALF_BIT     = CLKS_PER_BIT / 2;

    localparam IDLE  = 3'd0;
    localparam START = 3'd1;
    localparam DATA  = 3'd2;
    localparam STOP  = 3'd3;

    reg [2:0]  state     = IDLE;
    reg [15:0] clk_count = 16'd0;
    reg [2:0]  bit_index = 3'd0;
    reg [7:0]  rx_shift  = 8'd0;

    // Synchronize async RX input
    reg rx_sync_0 = 1'b1;
    reg rx_sync_1 = 1'b1;

    always @(posedge clk) begin
        rx_sync_0 <= rx;
        rx_sync_1 <= rx_sync_0;
    end

    always @(posedge clk) begin
        if (rst) begin
            state      <= IDLE;
            clk_count  <= 16'd0;
            bit_index  <= 3'd0;
            rx_shift   <= 8'd0;
            data_out   <= 8'd0;
            data_valid <= 1'b0;
        end else begin
            data_valid <= 1'b0;

            case (state)
                IDLE: begin
                    clk_count <= 16'd0;
                    bit_index <= 3'd0;

                    if (rx_sync_1 == 1'b0) begin
                        state <= START;
                    end
                end

                START: begin
                    if (clk_count == HALF_BIT) begin
                        if (rx_sync_1 == 1'b0) begin
                            clk_count <= 16'd0;
                            state <= DATA;
                        end else begin
                            state <= IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                DATA: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 16'd0;
                        rx_shift[bit_index] <= rx_sync_1;

                        if (bit_index == 3'd7) begin
                            bit_index <= 3'd0;
                            state <= STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                STOP: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count  <= 16'd0;
                        data_out   <= rx_shift;
                        data_valid <= 1'b1;
                        state      <= IDLE;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule