# Load demo_counter_seg7.bit onto Nexys A7-100T over JTAG (volatile, RAM only).
# Bitstream is lost on power-off. For persistent flashing see program_flash.tcl
# (not provided here).
#
# Run:
#   vivado -mode batch -source deployments/demo_counter_seg7/scripts/program.tcl

set script_dir [file dirname [file normalize [info script]]]
set deploy_dir [file dirname $script_dir]
set bit_file   $deploy_dir/out/demo_counter_seg7.bit

if {![file exists $bit_file]} {
    puts "ERROR: bitstream not found: $bit_file"
    puts "       Run build.tcl first."
    exit 1
}

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

# Target the Artix-7 100T (xc7a100t)
current_hw_device [lindex [get_hw_devices xc7a100t*] 0]
refresh_hw_device [current_hw_device]

set_property PROGRAM.FILE $bit_file [current_hw_device]
program_hw_devices [current_hw_device]

puts "Programmed -> $bit_file"

close_hw_target
disconnect_hw_server
close_hw_manager
