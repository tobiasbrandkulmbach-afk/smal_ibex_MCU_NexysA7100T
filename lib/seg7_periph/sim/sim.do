vlib work
vlog ../../peri_reg/rtl/peri_reg.sv \
     ../../seg7/rtl/seg7.sv \
     ../rtl/seg7_periph.sv \
     ../tb/tb_seg7_periph.sv
vsim -c tb_seg7_periph -do "run -all; quit"
