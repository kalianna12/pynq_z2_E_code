`timescale 1ns / 1ps

module ad7606_serial_reader #(
    parameter integer CLK_FREQ_HZ       = 125_000_000,
    parameter integer SCLK_DIV          = 25,
    parameter integer SAMPLE_COUNT      = 256,
    parameter integer RESET_HOLD_CLKS   = 1024,
    parameter integer CONVST_HIGH_CLKS  = 16
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        start,

    output reg         ad7606_reset,
    output reg         ad7606_convst_a,
    output reg         ad7606_convst_b,
    output reg         ad7606_cs_n,
    output reg         ad7606_sclk,
    input  wire        ad7606_douta,
    input  wire        ad7606_busy,

    output reg         busy,
    output reg         done,
    output reg signed [15:0] vin_max,
    output reg signed [15:0] vin_min,
    output reg signed [15:0] vout_max,
    output reg signed [15:0] vout_min,
    output reg [16:0]  vin_pp,
    output reg [16:0]  vout_pp
);

    localparam ST_IDLE       = 4'd0;
    localparam ST_RESET      = 4'd1;
    localparam ST_CONVST     = 4'd2;
    localparam ST_WAIT_BUSY1 = 4'd3;
    localparam ST_WAIT_BUSY0 = 4'd4;
    localparam ST_CS_SETUP   = 4'd5;
    localparam ST_SHIFT      = 4'd6;
    localparam ST_CS_HOLD    = 4'd7;
    localparam ST_NEXT       = 4'd8;
    localparam ST_DONE       = 4'd9;

    reg [3:0]  state;
    reg [15:0] delay_cnt;
    reg [15:0] sample_cnt;
    reg [5:0]  bit_cnt;
    reg [15:0] sclk_cnt;
    reg [31:0] shift_reg;
    reg        busy_d1;
    reg        busy_d2;

    wire signed [15:0] vin_sample  = shift_reg[31:16];
    wire signed [15:0] vout_sample = shift_reg[15:0];
    wire ad7606_busy_sync = busy_d2;

    function [16:0] pp_diff;
        input signed [15:0] max_v;
        input signed [15:0] min_v;
        reg signed [16:0] max_ext;
        reg signed [16:0] min_ext;
        begin
            max_ext = {max_v[15], max_v};
            min_ext = {min_v[15], min_v};
            pp_diff = max_ext - min_ext;
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            state           <= ST_IDLE;
            delay_cnt       <= 16'd0;
            sample_cnt      <= 16'd0;
            bit_cnt         <= 6'd0;
            sclk_cnt        <= 16'd0;
            shift_reg       <= 32'd0;
            busy_d1         <= 1'b0;
            busy_d2         <= 1'b0;
            ad7606_reset    <= 1'b0;
            ad7606_convst_a <= 1'b0;
            ad7606_convst_b <= 1'b0;
            ad7606_cs_n     <= 1'b1;
            ad7606_sclk     <= 1'b0;
            busy            <= 1'b0;
            done            <= 1'b0;
            vin_max         <= 16'sh8000;
            vin_min         <= 16'sh7FFF;
            vout_max        <= 16'sh8000;
            vout_min        <= 16'sh7FFF;
            vin_pp          <= 17'd0;
            vout_pp         <= 17'd0;
        end else begin
            busy_d1 <= ad7606_busy;
            busy_d2 <= busy_d1;
            done <= 1'b0;

            case (state)
                ST_IDLE: begin
                    ad7606_reset    <= 1'b0;
                    ad7606_convst_a <= 1'b0;
                    ad7606_convst_b <= 1'b0;
                    ad7606_cs_n     <= 1'b1;
                    ad7606_sclk     <= 1'b0;
                    busy            <= 1'b0;

                    if (start) begin
                        busy       <= 1'b1;
                        delay_cnt  <= 16'd0;
                        sample_cnt <= 16'd0;
                        vin_max    <= 16'sh8000;
                        vin_min    <= 16'sh7FFF;
                        vout_max   <= 16'sh8000;
                        vout_min   <= 16'sh7FFF;
                        vin_pp     <= 17'd0;
                        vout_pp    <= 17'd0;
                        state      <= ST_RESET;
                    end
                end

                ST_RESET: begin
                    ad7606_reset <= 1'b1;
                    if (delay_cnt == RESET_HOLD_CLKS - 1) begin
                        ad7606_reset <= 1'b0;
                        delay_cnt    <= 16'd0;
                        state        <= ST_CONVST;
                    end else begin
                        delay_cnt <= delay_cnt + 1'b1;
                    end
                end

                ST_CONVST: begin
                    ad7606_convst_a <= 1'b1;
                    ad7606_convst_b <= 1'b1;
                    if (delay_cnt == CONVST_HIGH_CLKS - 1) begin
                        ad7606_convst_a <= 1'b0;
                        ad7606_convst_b <= 1'b0;
                        delay_cnt       <= 16'd0;
                        state           <= ST_WAIT_BUSY1;
                    end else begin
                        delay_cnt <= delay_cnt + 1'b1;
                    end
                end

                ST_WAIT_BUSY1: begin
                    if (ad7606_busy_sync)
                        state <= ST_WAIT_BUSY0;
                end

                ST_WAIT_BUSY0: begin
                    if (!ad7606_busy_sync) begin
                        ad7606_cs_n <= 1'b0;
                        ad7606_sclk <= 1'b0;
                        sclk_cnt    <= 16'd0;
                        bit_cnt     <= 6'd0;
                        shift_reg   <= 32'd0;
                        state       <= ST_CS_SETUP;
                    end
                end

                ST_CS_SETUP: begin
                    state <= ST_SHIFT;
                end

                ST_SHIFT: begin
                    if (sclk_cnt == SCLK_DIV - 1) begin
                        sclk_cnt <= 16'd0;
                        ad7606_sclk <= ~ad7606_sclk;

                        if (ad7606_sclk) begin
                            shift_reg <= {shift_reg[30:0], ad7606_douta};
                            if (bit_cnt == 6'd31) begin
                                bit_cnt <= 6'd0;
                                state   <= ST_CS_HOLD;
                            end else begin
                                bit_cnt <= bit_cnt + 1'b1;
                            end
                        end
                    end else begin
                        sclk_cnt <= sclk_cnt + 1'b1;
                    end
                end

                ST_CS_HOLD: begin
                    ad7606_cs_n <= 1'b1;
                    ad7606_sclk <= 1'b0;

                    if (vin_sample > vin_max)   vin_max  <= vin_sample;
                    if (vin_sample < vin_min)   vin_min  <= vin_sample;
                    if (vout_sample > vout_max) vout_max <= vout_sample;
                    if (vout_sample < vout_min) vout_min <= vout_sample;

                    state <= ST_NEXT;
                end

                ST_NEXT: begin
                    if (sample_cnt == SAMPLE_COUNT - 1) begin
                        vin_pp  <= pp_diff(vin_max, vin_min);
                        vout_pp <= pp_diff(vout_max, vout_min);
                        state   <= ST_DONE;
                    end else begin
                        sample_cnt <= sample_cnt + 1'b1;
                        delay_cnt  <= 16'd0;
                        state      <= ST_CONVST;
                    end
                end

                ST_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
