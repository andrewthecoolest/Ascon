## clock, 100 MHz
set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## btnC
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports rst_btn]

## Chipwhisperer on JA
set_property -dict { PACKAGE_PIN J1 IOSTANDARD LVCMOS33 } [get_ports clk_out]  ;# JA1 to HS1
set_property -dict { PACKAGE_PIN L2 IOSTANDARD LVCMOS33 } [get_ports tx_pin]   ;# JA2 to TIO1
set_property -dict { PACKAGE_PIN J2 IOSTANDARD LVCMOS33 } [get_ports rx_pin]   ;# JA3 to TIO2
set_property -dict { PACKAGE_PIN G2 IOSTANDARD LVCMOS33 } [get_ports trigger]  ;# JA4 to TIO4
set_property -dict { PACKAGE_PIN H1 IOSTANDARD LVCMOS33 PULLUP TRUE } [get_ports nrst]  ;# JA7 to nRST

## usb uart, for testing without CW
## set_property -dict { PACKAGE_PIN B18 IOSTANDARD LVCMOS33 } [get_ports rx_pin]
## set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports tx_pin]

## async, no timing needed
set_false_path -from [get_ports rst_btn]
set_false_path -from [get_ports nrst]
set_false_path -from [get_ports rx_pin]
set_false_path -to [get_ports tx_pin]
set_false_path -to [get_ports trigger]
set_false_path -to [get_ports clk_out]

## config
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
