// Ibex standalone core - file list for synthesis and simulation.
// All paths relative to lib/ibex/ (i.e. the directory this file lives in).
//
// Register file choice
//   ibex_register_file_fpga.sv  <- use this for Xilinx / FPGA (RAM32M / LUTRAM)
//   ibex_register_file_ff.sv    <- flip-flop fallback (ASIC / sim)
//
// Include paths required (add to tool's +incdir or equivalent):
//   upstream/vendor/lowrisc_ip/ip/prim/rtl/
//   upstream/vendor/lowrisc_ip/dv/sv/dv_utils/
//
// prim_buf (Xilinx implementation):
//   upstream/vendor/lowrisc_ip/ip/prim_xilinx/rtl/prim_buf.sv

// --- prim support ---
upstream/vendor/lowrisc_ip/ip/prim_xilinx/rtl/prim_buf.sv

// --- ibex core (order matters: pkg first, core last) ---
upstream/rtl/ibex_pkg.sv
upstream/rtl/ibex_alu.sv
upstream/rtl/ibex_compressed_decoder.sv
upstream/rtl/ibex_controller.sv
upstream/rtl/ibex_counter.sv
upstream/rtl/ibex_csr.sv
upstream/rtl/ibex_cs_registers.sv
upstream/rtl/ibex_decoder.sv
upstream/rtl/ibex_ex_block.sv
upstream/rtl/ibex_id_stage.sv
upstream/rtl/ibex_if_stage.sv
upstream/rtl/ibex_load_store_unit.sv
upstream/rtl/ibex_multdiv_slow.sv
upstream/rtl/ibex_multdiv_fast.sv
upstream/rtl/ibex_prefetch_buffer.sv
upstream/rtl/ibex_fetch_fifo.sv
upstream/rtl/ibex_pmp.sv
upstream/rtl/ibex_wb_stage.sv
upstream/rtl/ibex_register_file_fpga.sv
upstream/rtl/ibex_core.sv

// --- lib-internal wrapper (must come AFTER ibex_core / register file) ---
rtl/ibex_top.sv
