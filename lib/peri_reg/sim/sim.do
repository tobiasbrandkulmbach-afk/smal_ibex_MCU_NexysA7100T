vlib work
vlog ../rtl/peri_reg.sv ../tb/tb_peri_reg.sv
vsim -c tb_peri_reg -do "run -all; quit"
