# Vivado non-project batch build for demo_counter_seg7.
# Run from anywhere:
#   vivado -mode batch -source deployments/demo_counter_seg7/scripts/build.tcl
# Output bitstream: deployments/demo_counter_seg7/out/demo_counter_seg7.bit

set script_dir   [file dirname [file normalize [info script]]]
set deploy_dir   [file dirname $script_dir]
set project_root [file dirname [file dirname $deploy_dir]]
set lib_dir      $project_root/lib
set out_dir      $deploy_dir/out

file mkdir $out_dir

# Vivado schreibt Nebenprodukte (clockInfo.txt, tight_setup_hold_pins.txt,
# .Xil/, Journale) ins aktuelle Verzeichnis -> in den (gitignored) out/-Ordner
# wechseln, damit sich nichts im Deployment-/Hauptordner stapelt.
cd $out_dir

set top  demo_counter_seg7
set part xc7a100tcsg324-1

# RTL sources (library + top)
read_verilog -sv $lib_dir/debouncer/rtl/debouncer.sv
read_verilog -sv $lib_dir/counter/rtl/counter.sv
read_verilog -sv $lib_dir/seg7/rtl/seg7.sv
read_verilog -sv $lib_dir/seg7_hex/rtl/seg7_hex.sv
read_verilog -sv $deploy_dir/rtl/$top.sv

# Physical constraints
read_xdc $deploy_dir/constraints/Nexys-A7-100T-Master.xdc

# Synthesis + implementation
synth_design -top $top -part $part

# Bitstream-Konfig fuer QSPI-Boot von der Nexys A7 (Spansion S25FL128S, x4 @33 MHz).
set_property CONFIG_VOLTAGE                 3.3   [current_design]
set_property CFGBVS                         VCCO  [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH  4     [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE    33    [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES   [current_design]

opt_design
place_design
route_design

# Reports
report_timing_summary -file $out_dir/timing.rpt
report_utilization    -file $out_dir/utilization.rpt
report_drc            -file $out_dir/drc.rpt

# Bitstream
write_bitstream -force $out_dir/$top.bit

# Flash-Image (.mcs) fuer den QSPI-Konfig-Flash der Nexys A7 (autonomer Boot).
write_cfgmem -force -format mcs -interface SPIx4 -size 16 \
    -loadbit "up 0x0 $out_dir/$top.bit" \
    -file $out_dir/$top.mcs

puts "Build complete:"
puts "  Bitstream:   $out_dir/$top.bit"
puts "  Flash-Image: $out_dir/$top.mcs"
