`timescale 1ns / 1ps

// DDS core: 32-bit phase accumulator + waveform generators
// wave_sel: 000=rising staircase, 001=sine, 010=square
//           011=T-mode (group toggle @ Fout)
//           100=fixed low, 101=fixed mid-scale, 110=fixed full-scale
//
// T-mode: t_group=0 → bits[7:0] toggle,  t_group=1 → bits[13:8] toggle
//
// Pipeline: 2-cycle latency, all paths aligned.
module dds_core #(
    parameter [31:0] FWORD = 32'd34360   // default 1KHz @ 125MHz
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        dds_en,
    input  wire        sample_tick,
    input  wire [2:0]  wave_sel,
    input  wire        t_group,          // 0=low-8, 1=high-6
    output reg  [13:0] dac_code
);

    // ============================================================
    // Phase accumulator
    // ============================================================
    reg [31:0] fre_acc;

    always @(posedge clk) begin
        if (rst)
            fre_acc <= 32'd0;
        else if (dds_en && sample_tick)
            fre_acc <= fre_acc + FWORD;
    end

    // ============================================================
    // T-mode toggle: square wave at Fout rate from phase MSB
    // ============================================================
    reg t_toggle;

    always @(posedge clk) begin
        if (rst)
            t_toggle <= 1'b0;
        else if (sample_tick)
            t_toggle <= fre_acc[31];
    end

    reg sample_tick_d1;
    reg sample_tick_d2;

    always @(posedge clk) begin
        if (rst) begin
            sample_tick_d1 <= 1'b0;
            sample_tick_d2 <= 1'b0;
        end else begin
            sample_tick_d1 <= sample_tick;
            sample_tick_d2 <= sample_tick_d1;
        end
    end

    // ============================================================
    // Pipeline stage 0: capture fre_acc bits
    // ============================================================
    reg [11:0] rom_addr_s0;
    reg [13:0] stair_s0;
    reg [13:0] square_s0;

    always @(posedge clk) begin
        if (rst) begin
            rom_addr_s0 <= 12'd0;
            stair_s0    <= 14'd0;
            square_s0   <= 14'd0;
        end else if (sample_tick) begin
            rom_addr_s0 <= fre_acc[31:20];
            stair_s0    <= fre_acc[31:18];
            square_s0   <= fre_acc[31] ? 14'h3FFF : 14'h0000;
        end
    end

    // ============================================================
    // Sine ROM (BRAM inferred, 1 cycle read latency)
    // ============================================================
    wire [13:0] sine_data;

    sine_rom u_sine_rom (
        .clk  (clk),
        .addr (rom_addr_s0),
        .dout (sine_data)
    );

    // ============================================================
    // Pipeline stage 1: align / MUX
    // ============================================================
    reg [13:0] stair_s1;
    reg [13:0] square_s1;
    reg [13:0] sine_s1;

    always @(posedge clk) begin
        if (rst) begin
            stair_s1  <= 14'd0;
            square_s1 <= 14'd0;
            sine_s1   <= 14'd0;
            dac_code  <= 14'd0;
        end else if (sample_tick_d1) begin
            stair_s1  <= stair_s0;
            square_s1 <= square_s0;
            sine_s1   <= sine_data;
        end else if (sample_tick_d2) begin

            case (wave_sel)
                3'b000:  dac_code <= stair_s1;
                3'b001:  dac_code <= sine_s1;
                3'b010:  dac_code <= square_s1;
                3'b011:  dac_code <= {14{t_toggle}};
                3'b100:  dac_code <= 14'd0;
                3'b101:  dac_code <= 14'd8192;
                3'b110:  dac_code <= 14'h3FFF;
                default: dac_code <= stair_s1;
            endcase
        end
    end

endmodule
