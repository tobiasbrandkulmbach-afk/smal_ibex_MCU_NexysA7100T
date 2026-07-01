vlib work
vlog ../../seg7/rtl/seg7.sv \
     ../rtl/seg7_hex.sv \
     ../tb/tb_seg7_hex.sv
vsim -c tb_seg7_hex -do "run -all; quit"
