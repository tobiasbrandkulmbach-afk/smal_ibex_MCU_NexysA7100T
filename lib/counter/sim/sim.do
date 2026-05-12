vlib work
vlog ../rtl/counter.sv ../tb/tb_counter.sv
vsim -c tb_counter -do "run -all; quit"
