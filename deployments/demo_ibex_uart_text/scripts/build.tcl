# Vivado non-project batch build for demo_ibex_uart_text.
# Run from anywhere:
#   vivado -mode batch -source deployments/demo_ibex_uart_text/scripts/build.tcl
# Output bitstream: deployments/demo_ibex_uart_text/out/demo_ibex_uart_text.bit

set script_dir   [file dirname [file normalize [info script]]]
set deploy_dir   [file dirname $script_dir]
set project_root [file dirname [file dirname $deploy_dir]]
set lib_dir      $project_root/lib
set out_dir      $deploy_dir/out

file mkdir $out_dir

set top  demo_ibex_uart_text
set part xc7a100tcsg324-1

# --- Library sources -----------------------------------------------------
# Ibex (Core + Register-File + Wrapper) - bringt seine eigenen Include-Pfade
# und seinen ibex_top-Wrapper mit. Muss vor den ibex_top-Konsumenten geladen
# werden.
source $lib_dir/ibex/ibex.tcl

read_verilog -sv $lib_dir/ram/rtl/ram.sv
read_verilog -sv $lib_dir/peri_reg/rtl/peri_reg.sv
read_verilog -sv $lib_dir/seg7/rtl/seg7.sv
read_verilog -sv $lib_dir/seg7_periph/rtl/seg7_periph.sv
read_verilog -sv $lib_dir/uart_tx/rtl/uart_tx.sv
read_verilog -sv $lib_dir/uart_rx/rtl/uart_rx.sv
read_verilog -sv $lib_dir/uart_periph/rtl/uart_periph.sv

# --- Deployment top ------------------------------------------------------
read_verilog -sv $deploy_dir/rtl/$top.sv

# --- Physical constraints ------------------------------------------------
read_xdc $deploy_dir/constraints/Nexys-A7-100T-Master.xdc

# Vivado schreibt Nebenprodukte (clockInfo.txt, tight_setup_hold_pins.txt,
# .Xil/, Journale) ins aktuelle Verzeichnis. Deshalb in den (gitignored)
# out/-Ordner wechseln und die .mem-Dateien fuer $readmemh dorthin spiegeln.
foreach _m [glob -nocomplain $deploy_dir/*.mem] { file copy -force $_m $out_dir }
cd $out_dir

# --- Synthesis + implementation ------------------------------------------
synth_design -top $top -part $part

# Bitstream-Konfig fuer QSPI-Boot von der Nexys A7 (Spansion S25FL128S, x4 @33 MHz).
# Diese Properties landen im Bitstream-Header und sagen dem FPGA beim Power-up,
# wie es sich selbst aus dem Onboard-Flash holen soll.
set_property CONFIG_VOLTAGE                 3.3   [current_design]
set_property CFGBVS                         VCCO  [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH  4     [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE    33    [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES   [current_design]

opt_design
place_design
route_design

# --- Routed checkpoint + Memory-Map-Info ---------------------------------
# Der Checkpoint erlaubt spaeter, die .mmi ohne erneute Synthese neu zu
# erzeugen. write_mem_info dokumentiert, in welchen physischen BRAMs die
# Speicher (imem/dmem) liegen - Grundlage fuer updatemem (siehe update_mem.tcl).
write_checkpoint -force $out_dir/$top.dcp
write_mem_info   -force $out_dir/$top.mmi

# --- Reports -------------------------------------------------------------
report_timing_summary -file $out_dir/timing.rpt
report_utilization    -file $out_dir/utilization.rpt
report_drc            -file $out_dir/drc.rpt

# --- Bitstream -----------------------------------------------------------
write_bitstream -force $out_dir/$top.bit

# --- Flash-Image (.mcs) fuer QSPI-Konfig-Flash der Nexys A7 --------------
# Wird in den Onboard-Flash gebrannt -> Bootet ohne PC.  Flashen separat
# via scripts/flash.tcl.
write_cfgmem -force -format mcs -interface SPIx4 -size 16 \
    -loadbit "up 0x0 $out_dir/$top.bit" \
    -file $out_dir/$top.mcs

puts "Build complete:"
puts "  Bitstream:   $out_dir/$top.bit  (JTAG flashen via program.tcl)"
puts "  Flash-Image: $out_dir/$top.mcs  (QSPI flashen via flash.tcl)"
