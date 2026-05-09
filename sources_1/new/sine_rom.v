`timescale 1ns / 1ps

// Sine ROM wrapper — instantiates Block Memory Generator IP
//
// IP 生成后，本模块例化名为 "sine_bram" 的 BMG IP。
// 如果 IP 名称不同，修改下方 u_sine_bram 的模块名。
module sine_rom (
    input  wire        clk,
    input  wire [11:0] addr,
    output wire [13:0] dout
);

    sine_bram u_sine_bram (
        .clka  (clk),
        .addra (addr),
        .douta (dout)
    );

endmodule
