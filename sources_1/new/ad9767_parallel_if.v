`timescale 1ns / 1ps

module ad9767_parallel_if #(
    parameter integer CLK_FREQ_HZ       = 125_000_000,
    parameter integer UPDATE_RATE_HZ    = 1_000_000,
    parameter integer DDS_LATENCY_CLKS  = 3,
    parameter integer DATA_SETUP_CLKS   = 2,
    parameter integer PULSE_HIGH_CLKS   = 2
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [13:0] sample_data,
    input  wire        pin_freq_mode,
    input  wire        pin_freq_dac_clk,
    input  wire        pin_freq_dac_wrt,

    output reg  [13:0] dac_data,
    output reg         dac_clk,
    output reg         dac_wrt,
    output reg         sample_tick
);

    localparam integer UPDATE_DIV = CLK_FREQ_HZ / UPDATE_RATE_HZ;

    localparam ST_IDLE      = 2'd0;
    localparam ST_WAIT_DATA = 2'd1;
    localparam ST_SETUP     = 2'd2;
    localparam ST_PULSE     = 2'd3;

    reg [1:0]  state        = ST_IDLE;
    reg [15:0] div_cnt      = 16'd0;
    reg [7:0]  wait_cnt     = 8'd0;
    reg [7:0]  setup_cnt    = 8'd0;
    reg [7:0]  pulse_cnt    = 8'd0;

    always @(posedge clk) begin
        if (rst) begin
            state       <= ST_IDLE;
            div_cnt     <= 16'd0;
            wait_cnt    <= 8'd0;
            setup_cnt   <= 8'd0;
            pulse_cnt   <= 8'd0;
            dac_data    <= 14'd0;
            dac_clk     <= 1'b0;
            dac_wrt     <= 1'b0;
            sample_tick <= 1'b0;
        end else begin
            sample_tick <= 1'b0;

            if (pin_freq_mode) begin
                state    <= ST_IDLE;
                div_cnt  <= 16'd0;
                dac_data <= sample_data;
                dac_clk  <= pin_freq_dac_clk;
                dac_wrt  <= pin_freq_dac_wrt;
            end else begin
                case (state)
                ST_IDLE: begin
                    dac_clk <= 1'b0;
                    dac_wrt <= 1'b0;

                    if (div_cnt == UPDATE_DIV - 1) begin
                        div_cnt     <= 16'd0;
                        wait_cnt    <= 8'd0;
                        sample_tick <= 1'b1;
                        state       <= ST_WAIT_DATA;
                    end else begin
                        div_cnt <= div_cnt + 1'b1;
                    end
                end

                ST_WAIT_DATA: begin
                    div_cnt <= div_cnt + 1'b1;
                    dac_clk <= 1'b0;
                    dac_wrt <= 1'b0;

                    if (wait_cnt == DDS_LATENCY_CLKS - 1) begin
                        wait_cnt  <= 8'd0;
                        setup_cnt <= 8'd0;
                        dac_data  <= sample_data;
                        state     <= ST_SETUP;
                    end else begin
                        wait_cnt <= wait_cnt + 1'b1;
                    end
                end

                ST_SETUP: begin
                    div_cnt <= div_cnt + 1'b1;
                    dac_clk <= 1'b0;
                    dac_wrt <= 1'b0;

                    if (setup_cnt == DATA_SETUP_CLKS - 1) begin
                        setup_cnt <= 8'd0;
                        pulse_cnt <= 8'd0;
                        dac_clk   <= 1'b1;
                        dac_wrt   <= 1'b1;
                        state     <= ST_PULSE;
                    end else begin
                        setup_cnt <= setup_cnt + 1'b1;
                    end
                end

                ST_PULSE: begin
                    div_cnt <= div_cnt + 1'b1;
                    if (pulse_cnt == PULSE_HIGH_CLKS - 1) begin
                        pulse_cnt <= 8'd0;
                        dac_clk   <= 1'b0;
                        dac_wrt   <= 1'b0;
                        state     <= ST_IDLE;
                    end else begin
                        pulse_cnt <= pulse_cnt + 1'b1;
                        dac_clk   <= 1'b1;
                        dac_wrt   <= 1'b1;
                    end
                end

                default: begin
                    state   <= ST_IDLE;
                    dac_clk <= 1'b0;
                    dac_wrt <= 1'b0;
                end
                endcase
            end
        end
    end

endmodule
