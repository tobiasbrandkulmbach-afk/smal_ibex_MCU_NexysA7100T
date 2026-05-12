vlib work
vlog ../rtl/debouncer.sv ../tb/tb_debouncer.sv
vsim -c tb_debouncer -do "run -all; quit"
