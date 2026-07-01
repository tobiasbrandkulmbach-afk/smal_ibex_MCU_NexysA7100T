// Deployment-Top: Ibex + IMEM + DMEM + Seg7 auf Nexys A7-100T.
//
// Memory map (CPU-Sicht):
//   0x0000_0000..0x0000_03FC   IMEM     1 KB  read-only, Initialisierung aus imem.mem
//                                              (Reset-Vektor: 0x0000_0080, Trap-Vektor: 0x0000_0000)
//   0x0001_0000..0x0001_3FFC   DMEM    16 KB  read/write, Initialisierung aus dmem.mem (0..4095)
//   0x8000_0000/0x8000_0004    SEG7    2 regs je 4 ASCII-Zeichen (Hardware-Font);
//                                              Reg-Auswahl ueber addr[2] (AN0..AN7).
//
// Bus-Fabric: Ibex hat zwei native Memory-Interfaces (instr / data). Das
// Fabric ist deshalb winzig (siehe unten "DATA BUS" und "INSTRUCTION BUS"):
//   * Adress-Dekoder erzeugt pro Slave ein chip-selects (sel_*)
//   * gnt = req (alle Slaves immer bereit)
//   * rvalid = req um einen Takt verzoegert (BRAM/peri_reg = 1-cycle read)
//   * rdata wird gemuxt anhand des registrierten sel-Vektors

module demo_ibex_seg7 (
    input  logic       clk_i,        // 100 MHz, pin E3
    input  logic       btnc_i,       // BTNC -> async reset (active-HIGH)

    output logic [7:0] an_o,         // 7-Segment Anoden, active-LOW
    output logic [7:0] seg_o         // 7-Segment Segmente {DP,G..A}, active-LOW
);

    // --------------------------------------------------------------------
    // Reset-Synchronizer
    //   btnc_i ist asynchron / active-HIGH; Ibex erwartet rst_ni synchron /
    //   active-LOW. Zwei-FF-Synchronizer auf ~btnc_i: kommt nach Bitstream-
    //   load (FFs init = 0) automatisch fuer ~2 Takte in Reset hoch.
    // --------------------------------------------------------------------
    logic rst_n_meta, rst_ni;
    always_ff @(posedge clk_i) begin
        rst_n_meta <= ~btnc_i;
        rst_ni     <= rst_n_meta;
    end

    // --------------------------------------------------------------------
    // Ibex-Signale (clean wires zum verkabeln)
    // --------------------------------------------------------------------
    logic        instr_req;
    logic        instr_gnt;
    logic        instr_rvalid;
    logic [31:0] instr_addr;
    logic [31:0] instr_rdata;
    logic        instr_err;

    logic        data_req;
    logic        data_gnt;
    logic        data_rvalid;
    logic        data_we;
    logic [3:0]  data_be;
    logic [31:0] data_addr;
    logic [31:0] data_wdata;
    logic [31:0] data_rdata;
    logic        data_err;

    ibex_top #(
        .BootAddr (32'h0000_0000),
        .HartId   (32'h0000_0000)
    ) u_cpu (
        .clk_i,
        .rst_ni,

        .instr_req_o    (instr_req),
        .instr_gnt_i    (instr_gnt),
        .instr_rvalid_i (instr_rvalid),
        .instr_addr_o   (instr_addr),
        .instr_rdata_i  (instr_rdata),
        .instr_err_i    (instr_err),

        .data_req_o     (data_req),
        .data_gnt_i     (data_gnt),
        .data_rvalid_i  (data_rvalid),
        .data_we_o      (data_we),
        .data_be_o      (data_be),
        .data_addr_o    (data_addr),
        .data_wdata_o   (data_wdata),
        .data_rdata_i   (data_rdata),
        .data_err_i     (data_err)
    );

    // ====================================================================
    //                            INSTRUCTION BUS
    // ====================================================================
    // Nur ein Slave (IMEM). Daher kein Mux, nur Adresse durchreichen und
    // gnt/rvalid generieren.
    //
    //   IMEM AddrWidth=8 -> 256 Woerter = 1 KB. addr_i ist wortindiziert,
    //   also instr_addr[9:2] verwenden (untere 2 Bits sind Byte-offset).
    // --------------------------------------------------------------------
    logic instr_rvalid_q;
    always_ff @(posedge clk_i) begin
        if (!rst_ni) instr_rvalid_q <= 1'b0;
        else         instr_rvalid_q <= instr_req;
    end

    assign instr_gnt    = instr_req;     // immer bereit
    assign instr_rvalid = instr_rvalid_q;
    assign instr_err    = 1'b0;

    // IMEM als XPM-Block-RAM. Funktional identisch zum ram-Modul (1-Takt
    // synchroner Read, read-only, Init aus imem.mem), aber als XPM-Makro -
    // nur dafuer erzeugt write_mem_info eine .mmi, die updatemem braucht, um
    // das Programm spaeter ohne Neu-Synthese in den Bitstream zu patchen.
    xpm_memory_spram #(
        .ADDR_WIDTH_A       (8),
        .MEMORY_SIZE        (256 * 32),     // Tiefe * Breite [bit] = 256 Woerter
        .MEMORY_PRIMITIVE   ("block"),
        .MEMORY_INIT_FILE   ("imem.mem"),   // $readmemh-Format wie bisher
        .WRITE_DATA_WIDTH_A (32),
        .READ_DATA_WIDTH_A  (32),
        .BYTE_WRITE_WIDTH_A (32),
        .READ_LATENCY_A     (1),
        .WRITE_MODE_A       ("read_first")
    ) u_imem (
        .clka           (clk_i),
        .ena            (instr_req),
        .wea            (1'b0),             // read-only
        .addra          (instr_addr[9:2]),
        .dina           (32'h0),
        .douta          (instr_rdata),
        .regcea         (1'b1),
        .rsta           (1'b0),
        .sleep          (1'b0),
        .injectsbiterra (1'b0),
        .injectdbiterra (1'b0),
        .sbiterra       (),
        .dbiterra       ()
    );

    // ====================================================================
    //                              DATA BUS
    // ====================================================================
    // Zwei Slaves:
    //   DMEM @ 0x0001_0000..0x0001_3FFC  (16 KB)   -> Vergleich auf addr[31:14] == 18'h00004
    //   SEG7 @ 0x8000_0000/0x8000_0004   (2 Regs)  -> addr[31:28] == 4'h8, Reg = addr[2]
    //
    // gnt = req (alle Slaves sind immer bereit).
    // rvalid = req_q1 (BRAM/peri_reg liefern rdata einen Takt spaeter).
    // rdata = sel_q1-gemuxt aus den jeweiligen Slave-Ausgaengen.
    // --------------------------------------------------------------------
    logic sel_dmem;
    logic sel_seg7;
    assign sel_dmem = (data_addr[31:14] == 18'h00004);
    assign sel_seg7 = (data_addr[31:28] ==  4'h8);

    // Per-Slave Requests
    logic dmem_req;
    logic seg7_req;
    assign dmem_req = data_req & sel_dmem;
    assign seg7_req = data_req & sel_seg7;

    // 1-Takt verzoegerter sel-Vektor fuer den Read-Data-Mux
    logic sel_dmem_q, sel_seg7_q;
    logic data_rvalid_q;
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            sel_dmem_q    <= 1'b0;
            sel_seg7_q    <= 1'b0;
            data_rvalid_q <= 1'b0;
        end else begin
            sel_dmem_q    <= dmem_req;
            sel_seg7_q    <= seg7_req;
            data_rvalid_q <= data_req;
        end
    end

    // Slave-Ausgaben
    logic [31:0] dmem_rdata;
    logic [31:0] seg7_rdata;

    ram #(
        .DataWidth (32),
        .AddrWidth (12),
        .MemFile   ("dmem.mem")
    ) u_dmem (
        .clk_i,
        .req_i   (dmem_req),
        .we_i    (data_we),
        .be_i    (data_be),
        .addr_i  (data_addr[13:2]),     // 12-bit Wortindex
        .wdata_i (data_wdata),
        .rdata_o (dmem_rdata)
    );

    seg7_periph u_seg7 (
        .clk_i,
        .rst_ni,
        .req_i   (seg7_req),
        .we_i    (data_we),
        .be_i    (data_be),
        .addr_i  (data_addr[2]),      // 0 = CHARS_LO, 1 = CHARS_HI
        .wdata_i (data_wdata),
        .rdata_o (seg7_rdata),
        .an_o,
        .seg_o
    );

    // Read-Data-Mux (1-Takt nach dem Request)
    assign data_gnt    = data_req;
    assign data_rvalid = data_rvalid_q;
    assign data_err    = 1'b0;
    assign data_rdata  = sel_dmem_q ? dmem_rdata :
                         sel_seg7_q ? seg7_rdata :
                                      32'h0;

endmodule
