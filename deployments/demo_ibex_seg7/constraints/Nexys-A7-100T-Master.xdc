## Nexys A7-100T pin constraints for demo_ibex_seg7.
## All used I/Os are LVCMOS33.

## 100 MHz onboard oscillator
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk_i }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk_i }];

## Buttons (active-HIGH on the board)
set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports { btnc_i }];   ## BTNC - reset

## 7-segment display - segments (shared across all 8 digits), active-LOW
set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports { seg_o[0] }]; ## CA
set_property -dict { PACKAGE_PIN R10   IOSTANDARD LVCMOS33 } [get_ports { seg_o[1] }]; ## CB
set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS33 } [get_ports { seg_o[2] }]; ## CC
set_property -dict { PACKAGE_PIN K13   IOSTANDARD LVCMOS33 } [get_ports { seg_o[3] }]; ## CD
set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports { seg_o[4] }]; ## CE
set_property -dict { PACKAGE_PIN T11   IOSTANDARD LVCMOS33 } [get_ports { seg_o[5] }]; ## CF
set_property -dict { PACKAGE_PIN L18   IOSTANDARD LVCMOS33 } [get_ports { seg_o[6] }]; ## CG
set_property -dict { PACKAGE_PIN H15   IOSTANDARD LVCMOS33 } [get_ports { seg_o[7] }]; ## DP

## 7-segment display - anodes (one per digit), active-LOW
set_property -dict { PACKAGE_PIN J17   IOSTANDARD LVCMOS33 } [get_ports { an_o[0] }];  ## AN0 (rightmost)
set_property -dict { PACKAGE_PIN J18   IOSTANDARD LVCMOS33 } [get_ports { an_o[1] }];  ## AN1
set_property -dict { PACKAGE_PIN T9    IOSTANDARD LVCMOS33 } [get_ports { an_o[2] }];  ## AN2
set_property -dict { PACKAGE_PIN J14   IOSTANDARD LVCMOS33 } [get_ports { an_o[3] }];  ## AN3
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { an_o[4] }];  ## AN4
set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS33 } [get_ports { an_o[5] }];  ## AN5
set_property -dict { PACKAGE_PIN K2    IOSTANDARD LVCMOS33 } [get_ports { an_o[6] }];  ## AN6
set_property -dict { PACKAGE_PIN U13   IOSTANDARD LVCMOS33 } [get_ports { an_o[7] }];  ## AN7 (leftmost)
