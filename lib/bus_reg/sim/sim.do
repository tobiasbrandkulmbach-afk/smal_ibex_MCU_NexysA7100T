vlib work
vlog ../rtl/bus_reg.sv ../tb/tb_bus_reg.sv
vsim -c tb_bus_reg -do "run -all; quit"
