`timescale 1ns / 1ps

// DDS core: 32-bit phase accumulator + 3 waveform generators
// wave_sel: 00=rising staircase, 01=sine, 10=square
module dds_core #(
    parameter [31:0] FWORD = 32'd34360   // default 1KHz @ 125MHz
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        dds_en,           // 1 = run, 0 = pause (freeze phase)
    input  wire [1:0]  wave_sel,
    output reg  [13:0] dac_code
);

    reg [31:0] fre_acc;

    // ---- phase accumulator ----
    always @(posedge clk) begin
        if (rst)
            fre_acc <= 32'd0;
        else if (dds_en)
            fre_acc <= fre_acc + FWORD;
    end

    // ---- sine ROM ----
    wire [11:0] rom_addr = fre_acc[31:20];
    wire [13:0] sine_data;

    sine_rom u_sine_rom (
        .clk  (clk),
        .addr (rom_addr),
        .dout (sine_data)
    );

    // ---- waveform select + output register ----
    always @(posedge clk) begin
        if (rst) begin
            dac_code <= 14'd0;
        end else begin
            case (wave_sel)
                2'b00:   dac_code <= fre_acc[31:18];                  // rising staircase
                2'b01:   dac_code <= sine_data;                       // sine (1 cycle latency, negligible)
                2'b10:   dac_code <= fre_acc[31] ? 14'h3FFF : 14'h0;  // square
                default: dac_code <= fre_acc[31:18];
            endcase
        end
    end

endmodule
