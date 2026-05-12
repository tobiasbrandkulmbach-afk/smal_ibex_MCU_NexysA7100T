vlib work
vlog ../rtl/seg7.sv ../tb/tb_seg7.sv
vsim -c tb_seg7 -do "run -all; quit"
