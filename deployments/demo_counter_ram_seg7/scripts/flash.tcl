# Brennt das .mcs in den QSPI-Konfig-Flash der Nexys A7 (S25FL128S).
# Nach diesem Schritt: JP1 auf "QSPI", Power-Cycle -> FPGA bootet
# eigenstaendig ohne PC.
#
# Voraussetzung: build.tcl wurde vorher gelaufen (Bitstream + MCS in out/).
#
# Run:
#   vivado -mode batch -source deployments/demo_counter_ram_seg7/scripts/flash.tcl

set script_dir [file dirname [file normalize [info script]]]
set deploy_dir [file dirname $script_dir]
set top        demo_counter_ram_seg7
set mcs_file   $deploy_dir/out/$top.mcs

if {![file exists $mcs_file]} {
    puts "ERROR: MCS-Image nicht gefunden: $mcs_file"
    puts "       build.tcl vorher laufen lassen."
    exit 1
}

# --- HW-Manager oeffnen, JTAG verbinden ---------------------------------
open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

current_hw_device [lindex [get_hw_devices xc7a100t*] 0]
refresh_hw_device [current_hw_device]

# Voraussetzung: Board wurde frisch power-cycled, JP1 auf JTAG.  Dann
# zeigt 'refresh_hw_device' DONE=0 (FPGA leer) und Vivados Indirect-SPI-
# Bridge kann ungestoert vom alten User-Bitstream loslegen.
# Falls hier "DONE status = 1" gemeldet wird, ist noch ein User-Design
# aktiv -> Board power-cyceln und Skript neu starten.

# --- Konfig-Flash an die FPGA-Device anhaengen --------------------------
# QSPI-Flash der Nexys A7-100T: Spansion S25FL128S. Dieser Part ist in der
# Vivado-GUI verifiziert.
set flash_id   s25fl128sxxxxxx0-spi-x1_x2_x4
set flash_part [lindex [get_cfgmem_parts $flash_id] 0]
if {$flash_part eq ""} {
    puts "ERROR: Flash-Part $flash_id nicht in Vivado gefunden."
    puts "       Liste auf: get_cfgmem_parts -all"
    exit 1
}
puts "Flash-Part: $flash_part"

create_hw_cfgmem -hw_device [current_hw_device] -mem_dev $flash_part
set cfgmem [get_property PROGRAM.HW_CFGMEM [current_hw_device]]

# --- Programmier-Optionen setzen ----------------------------------------
set_property PROGRAM.FILES                   [list $mcs_file] $cfgmem
set_property PROGRAM.ADDRESS_RANGE           use_file         $cfgmem
set_property PROGRAM.UNUSED_PIN_TERMINATION  pull-none        $cfgmem
set_property PROGRAM.BLANK_CHECK             0                $cfgmem
set_property PROGRAM.ERASE                   1                $cfgmem
set_property PROGRAM.CFG_PROGRAM             1                $cfgmem
set_property PROGRAM.VERIFY                  1                $cfgmem

# --- FPGA mit der Flash-Programmier-Bridge laden ------------------------
# Indirektes QSPI-Flashen laeuft ueber eine kleine SPI-Bridge IM FPGA. Die
# GUI laedt sie automatisch; im Batch-Flow muss das explizit passieren,
# sonst scheitert program_hw_cfgmem sofort mit "Failure to set flash
# parameters".
create_hw_bitstream -hw_device [current_hw_device] \
    [get_property PROGRAM.HW_CFGMEM_BITFILE [current_hw_device]]
program_hw_devices [current_hw_device]
refresh_hw_device  [current_hw_device]

# --- Brennen (dauert ~30-60s) -------------------------------------------
puts "Flashe $mcs_file in den QSPI-Konfig-Flash ..."
program_hw_cfgmem -hw_cfgmem $cfgmem

puts "Fertig. JP1 auf QSPI, Power-Cycle -> Board laeuft autonom."

close_hw_target
disconnect_hw_server
close_hw_manager
