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

set top  demo_counter_seg7
set part xc7a100tcsg324-1

# RTL sources (library + top)
read_verilog -sv $lib_dir/debouncer/rtl/debouncer.sv
read_verilog -sv $lib_dir/counter/rtl/counter.sv
read_verilog -sv $lib_dir/seg7/rtl/seg7.sv
read_verilog -sv $deploy_dir/rtl/$top.sv

# Physical constraints
read_xdc $deploy_dir/constraints/Nexys-A7-100T-Master.xdc

# Synthesis + implementation
synth_design -top $top -part $part
opt_design
place_design
route_design

# Reports
report_timing_summary -file $out_dir/timing.rpt
report_utilization    -file $out_dir/utilization.rpt
report_drc            -file $out_dir/drc.rpt

# Bitstream
write_bitstream -force $out_dir/$top.bit

puts "Build complete -> $out_dir/$top.bit"
