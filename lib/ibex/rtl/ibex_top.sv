// Lib-internal Ibex top-level wrapper.
//
// Wickelt ibex_core + ibex_register_file_fpga und blendet die Deployment-
// irrelevanten Schnittstellen aus (Icache-RAM-Ports, Debug, RVFI, Scramble,
// Interrupts, CPU-Control). Nach aussen bleibt nur das blanke Ibex Memory-
// Protocol (instr_*/data_*), plus clk/rst und BootAddr.
//
// Namens-Hinweis: lib/ibex/upstream/rtl/ibex_top.sv heisst genauso und ist
// absichtlich NICHT in files.f/ibex.tcl gelistet, damit dieser Wrapper den
// Modulnamen `ibex_top` exklusiv beansprucht.
module ibex_top import ibex_pkg::*; #(
    parameter logic [31:0] BootAddr = 32'h0000_0000,
    parameter logic [31:0] HartId   = 32'h0000_0000
) (
    input  logic        clk_i,
    input  logic        rst_ni,

    // Instruction memory interface (read-only)
    output logic        instr_req_o,
    input  logic        instr_gnt_i,
    input  logic        instr_rvalid_i,
    output logic [31:0] instr_addr_o,
    input  logic [31:0] instr_rdata_i,
    input  logic        instr_err_i,

    // Data memory interface (load/store)
    output logic        data_req_o,
    input  logic        data_gnt_i,
    input  logic        data_rvalid_i,
    output logic        data_we_o,
    output logic [3:0]  data_be_o,
    output logic [31:0] data_addr_o,
    output logic [31:0] data_wdata_o,
    input  logic [31:0] data_rdata_i,
    input  logic        data_err_i
);

    // -----------------------------------------------------------------
    // Register file (LUTRAM-friendly variant - infers RAM32M on Xilinx)
    // -----------------------------------------------------------------
    logic        dummy_instr_id;
    logic        dummy_instr_wb;
    logic [4:0]  rf_raddr_a;
    logic [4:0]  rf_raddr_b;
    logic [4:0]  rf_waddr_wb;
    logic        rf_we_wb;
    logic [31:0] rf_wdata_wb;
    logic [31:0] rf_rdata_a;
    logic [31:0] rf_rdata_b;

    ibex_register_file_fpga #(
        .RV32E             (1'b0),
        .DataWidth         (32),
        .DummyInstructions (1'b0)
    ) u_rf (
        .clk_i,
        .rst_ni,
        .test_en_i        (1'b0),
        .dummy_instr_id_i (dummy_instr_id),
        .dummy_instr_wb_i (dummy_instr_wb),
        .raddr_a_i        (rf_raddr_a),
        .rdata_a_o        (rf_rdata_a),
        .raddr_b_i        (rf_raddr_b),
        .rdata_b_o        (rf_rdata_b),
        .waddr_a_i        (rf_waddr_wb),
        .wdata_a_i        (rf_wdata_wb),
        .we_a_i           (rf_we_wb)
    );

    // -----------------------------------------------------------------
    // Tied-off Icache RAM ports (ICache = 0 -> Werte werden nicht genutzt,
    // muessen aber sauber getrieben werden, sonst Vivado-Warnungen).
    // -----------------------------------------------------------------
    logic [IC_TAG_SIZE-1:0]  ic_tag_rdata_zero  [IC_NUM_WAYS];
    logic [IC_LINE_SIZE-1:0] ic_data_rdata_zero [IC_NUM_WAYS];
    always_comb begin
        for (int i = 0; i < IC_NUM_WAYS; i++) begin
            ic_tag_rdata_zero[i]  = '0;
            ic_data_rdata_zero[i] = '0;
        end
    end

    // -----------------------------------------------------------------
    // Ibex core
    // -----------------------------------------------------------------
    ibex_core #(
        .PMPEnable         (1'b0),
        .MHPMCounterNum    (0),
        .RV32E             (1'b0),
        .RV32M             (RV32MFast),
        .RV32B             (RV32BNone),
        .BranchTargetALU   (1'b0),
        .WritebackStage    (1'b0),
        .ICache            (1'b0),
        .ICacheECC         (1'b0),
        .BranchPredictor   (1'b0),
        .DbgTriggerEn      (1'b0),
        .ResetAll          (1'b0),
        .SecureIbex        (1'b0),
        .DummyInstructions (1'b0),
        .RegFileECC        (1'b0),
        .RegFileDataWidth  (32),
        .MemECC            (1'b0)
    ) u_core (
        .clk_i,
        .rst_ni,

        .hart_id_i   (HartId),
        .boot_addr_i (BootAddr),

        // Instruction memory
        .instr_req_o,
        .instr_gnt_i,
        .instr_rvalid_i,
        .instr_addr_o,
        .instr_rdata_i,
        .instr_err_i,

        // Data memory
        .data_req_o,
        .data_gnt_i,
        .data_rvalid_i,
        .data_we_o,
        .data_be_o,
        .data_addr_o,
        .data_wdata_o,
        .data_rdata_i,
        .data_err_i,

        // Register file interface
        .dummy_instr_id_o  (dummy_instr_id),
        .dummy_instr_wb_o  (dummy_instr_wb),
        .rf_raddr_a_o      (rf_raddr_a),
        .rf_raddr_b_o      (rf_raddr_b),
        .rf_waddr_wb_o     (rf_waddr_wb),
        .rf_we_wb_o        (rf_we_wb),
        .rf_wdata_wb_ecc_o (rf_wdata_wb),
        .rf_rdata_a_ecc_i  (rf_rdata_a),
        .rf_rdata_b_ecc_i  (rf_rdata_b),

        // Icache RAM ports - tied off (ICache = 0)
        .ic_tag_req_o       (),
        .ic_tag_write_o     (),
        .ic_tag_addr_o      (),
        .ic_tag_wdata_o     (),
        .ic_tag_rdata_i     (ic_tag_rdata_zero),
        .ic_data_req_o      (),
        .ic_data_write_o    (),
        .ic_data_addr_o     (),
        .ic_data_wdata_o    (),
        .ic_data_rdata_i    (ic_data_rdata_zero),
        .ic_scr_key_valid_i (1'b0),
        .ic_scr_key_req_o   (),

        // Interrupts - alle aus
        .irq_software_i (1'b0),
        .irq_timer_i    (1'b0),
        .irq_external_i (1'b0),
        .irq_fast_i     (15'b0),
        .irq_nm_i       (1'b0),
        .irq_pending_o  (),

        // Debug - aus
        .debug_req_i         (1'b0),
        .crash_dump_o        (),
        .double_fault_seen_o (),

        // CPU-Control: Fetch dauerhaft an
        .fetch_enable_i         (IbexMuBiOn),
        .alert_minor_o          (),
        .alert_major_internal_o (),
        .alert_major_bus_o      (),
        .core_busy_o            ()
    );

endmodule
