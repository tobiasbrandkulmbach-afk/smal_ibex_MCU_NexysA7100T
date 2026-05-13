# ibex.tcl - source this from a deployment build.tcl to add the ibex core.
#
# Requires $lib_dir to be set by the caller (absolute path to lib/).
# Example usage in build.tcl:
#
#   set lib_dir [file normalize [file join [file dirname [info script]] ../../lib]]
#   source $lib_dir/ibex/ibex.tcl

set ibex_dir [file join $lib_dir ibex upstream]

# Include paths for `include "prim_assert.sv" and `include "dv_fcov_macros.svh"
set_property include_dirs [list \
    [file join $ibex_dir vendor lowrisc_ip ip prim rtl] \
    [file join $ibex_dir vendor lowrisc_ip dv sv dv_utils] \
] [current_fileset]

# prim_buf (Xilinx implementation - needed by ibex_core)
read_verilog -sv [file join $ibex_dir vendor lowrisc_ip ip prim_xilinx rtl prim_buf.sv]

# ibex core RTL (order: pkg first, ibex_core last)
read_verilog -sv [list \
    [file join $ibex_dir rtl ibex_pkg.sv]                \
    [file join $ibex_dir rtl ibex_alu.sv]                \
    [file join $ibex_dir rtl ibex_compressed_decoder.sv] \
    [file join $ibex_dir rtl ibex_controller.sv]         \
    [file join $ibex_dir rtl ibex_counter.sv]            \
    [file join $ibex_dir rtl ibex_csr.sv]                \
    [file join $ibex_dir rtl ibex_cs_registers.sv]       \
    [file join $ibex_dir rtl ibex_decoder.sv]            \
    [file join $ibex_dir rtl ibex_ex_block.sv]           \
    [file join $ibex_dir rtl ibex_id_stage.sv]           \
    [file join $ibex_dir rtl ibex_if_stage.sv]           \
    [file join $ibex_dir rtl ibex_load_store_unit.sv]    \
    [file join $ibex_dir rtl ibex_multdiv_slow.sv]       \
    [file join $ibex_dir rtl ibex_multdiv_fast.sv]       \
    [file join $ibex_dir rtl ibex_prefetch_buffer.sv]    \
    [file join $ibex_dir rtl ibex_fetch_fifo.sv]         \
    [file join $ibex_dir rtl ibex_pmp.sv]                \
    [file join $ibex_dir rtl ibex_wb_stage.sv]           \
    [file join $ibex_dir rtl ibex_register_file_fpga.sv] \
    [file join $ibex_dir rtl ibex_core.sv]               \
]

# lib-internal wrapper (depends on ibex_core + register file above)
read_verilog -sv [file join $lib_dir ibex rtl ibex_top.sv]
