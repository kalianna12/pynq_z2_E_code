## ============================================================
## PYNQ-Z2 UART TX/RX Echo + AD9767 P1/CH1 Square Test
## ============================================================

## 125 MHz PL clock
set_property PACKAGE_PIN H16 [get_ports clk_125m]
set_property IOSTANDARD LVCMOS33 [get_ports clk_125m]
create_clock -period 8.000 -name clk_125m [get_ports clk_125m]

## Reset button: BTN0
set_property PACKAGE_PIN D19 [get_ports rst_btn]
set_property IOSTANDARD LVCMOS33 [get_ports rst_btn]

## UART via PMODB
## PMODB Pin 1 = W14 = FPGA uart_tx -> USB-TTL RXD
set_property PACKAGE_PIN W14 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

## PMODB Pin 2 = Y14 = USB-TTL TXD -> FPGA uart_rx
set_property PACKAGE_PIN Y14 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]

## LEDs
set_property PACKAGE_PIN R14 [get_ports led0]
set_property IOSTANDARD LVCMOS33 [get_ports led0]

set_property PACKAGE_PIN P14 [get_ports led1]
set_property IOSTANDARD LVCMOS33 [get_ports led1]

set_property PACKAGE_PIN N16 [get_ports led2]
set_property IOSTANDARD LVCMOS33 [get_ports led2]

set_property PACKAGE_PIN M14 [get_ports led3]
set_property IOSTANDARD LVCMOS33 [get_ports led3]

## ============================================================
## AD9767 DAC P1 / CH1 hardware test
## J6-20 = P1_DB0,  J6-19 = P1_DB1,  J6-18 = P1_DB2,  J6-17 = P1_DB3
## J6-16 = P1_DB4,  J6-15 = P1_DB5,  J6-14 = P1_DB6,  J6-13 = P1_DB7
## J6-12 = P1_DB8,  J6-11 = P1_DB9,  J6-10 = P1_DB10, J6-9  = P1_DB11
## J6-8  = P1_DB12, J6-7  = P1_DB13, J6-22 = CLK1,    J6-21 = WRT1
## J6-1  = DVCC5V module power, J6-2 = DGND
## ============================================================

set_property PACKAGE_PIN W18 [get_ports {dac_data[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dac_data[0]}]

set_property PACKAGE_PIN W19 [get_ports {dac_data[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dac_data[1]}]

set_property PACKAGE_PIN V6 [get_ports {dac_data[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dac_data[2]}]

set_property PACKAGE_PIN Y18 [get_ports {dac_data[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dac_data[3]}]

set_property PACKAGE_PIN Y19 [get_ports {dac_data[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dac_data[4]}]

set_property PACKAGE_PIN U7 [get_ports {dac_data[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dac_data[5]}]

set_property PACKAGE_PIN C20 [get_ports {dac_data[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dac_data[6]}]

set_property PACKAGE_PIN V7 [get_ports {dac_data[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dac_data[7]}]

set_property PACKAGE_PIN U8 [get_ports {dac_data[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dac_data[8]}]

set_property PACKAGE_PIN W6 [get_ports {dac_data[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dac_data[9]}]

set_property PACKAGE_PIN U18 [get_ports {dac_data[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dac_data[10]}]

set_property PACKAGE_PIN V8 [get_ports {dac_data[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dac_data[11]}]

set_property PACKAGE_PIN V10 [get_ports {dac_data[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dac_data[12]}]

set_property PACKAGE_PIN U19 [get_ports {dac_data[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dac_data[13]}]

set_property PACKAGE_PIN W10 [get_ports dac_clk]
set_property IOSTANDARD LVCMOS33 [get_ports dac_clk]

set_property PACKAGE_PIN F19 [get_ports dac_wrt]
set_property IOSTANDARD LVCMOS33 [get_ports dac_wrt]
