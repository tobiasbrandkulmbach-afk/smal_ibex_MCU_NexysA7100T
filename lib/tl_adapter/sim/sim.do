vlib work
vlog ../../tlul_pkg/rtl/tlul_pkg.sv ../../ram/rtl/ram.sv ../rtl/tl_adapter.sv ../tb/tb_tl_adapter.sv
vsim -c tb_tl_adapter -do "run -all; quit"
