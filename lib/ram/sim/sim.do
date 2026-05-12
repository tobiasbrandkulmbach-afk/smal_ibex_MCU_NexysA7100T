vlib work
vlog ../rtl/ram.sv ../tb/tb_ram.sv
vsim -c tb_ram -do "run -all; quit"
