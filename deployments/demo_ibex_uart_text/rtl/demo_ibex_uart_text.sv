// Deployment-Top: Ibex + IMEM + DMEM + Seg7(Zeichen) + UART auf Nexys A7-100T.
//
// Lauftext-Demo: jedes ueber die USB-UART empfangene Zeichen wird als Buchstabe
// auf der 8-stelligen 7-Segment-Anzeige dargestellt und nach links geschoben
// (neues Zeichen erscheint rechts an AN0). Die 7-Segment-Peripherie nutzt jetzt
// zwei 32-Bit-Register (je 4 ASCII-Zeichen) und einen Hardware-Font.
//
// Memory map (CPU-Sicht):
//   0x0000_0000..0x0000_03FC   IMEM     1 KB  read-only (Code), Init aus imem.mem
//   0x0001_0000..0x0001_3FFC   DMEM    16 KB  read/write (Daten), Init aus dmem.mem
//   0x8000_0000                SEG7_LO  W/R: ASCII fuer Stellen 0..3 (AN0..AN3)
//   0x8000_0004                SEG7_HI  W/R: ASCII fuer Stellen 4..7 (AN4..AN7)
//   0x9000_0000                UART_DATA   W: low byte senden / R: empfangenes Byte
//   0x9000_0004                UART_STATUS R: bit0 tx_ready, bit1 rx_valid, bit2 overrun
module demo_ibex_uart_text (
    input  logic       clk_i,        // 100 MHz, pin E3
    input  logic       btnc_i,       // BTNC -> async reset (active-HIGH)

    output logic [7:0] an_o,         // 7-Segment Anoden, active-LOW
    output logic [7:0] seg_o,        // 7-Segment Segmente {DP,G..A}, active-LOW

    output logic       uart_tx_o,    // USB-UART: FPGA -> PC (Pin C4)
    input  logic       uart_rx_i     // USB-UART: PC -> FPGA (Pin D4)
);

    // --------------------------------------------------------------------
    // Reset-Synchronizer (btnc_i async/active-HIGH -> rst_ni sync/active-LOW)
    // --------------------------------------------------------------------
    logic rst_n_meta, rst_ni;
    always_ff @(posedge clk_i) begin
        rst_n_meta <= ~btnc_i;
        rst_ni     <= rst_n_meta;
    end

    // --------------------------------------------------------------------
    // Ibex-Signale
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
    logic instr_rvalid_q;
    always_ff @(posedge clk_i) begin
        if (!rst_ni) instr_rvalid_q <= 1'b0;
        else         instr_rvalid_q <= instr_req;
    end

    assign instr_gnt    = instr_req;
    assign instr_rvalid = instr_rvalid_q;
    assign instr_err    = 1'b0;

    // IMEM als XPM-Block-RAM (Single-Port, nur Code; Daten liegen im DMEM).
    xpm_memory_spram #(
        .ADDR_WIDTH_A       (8),
        .MEMORY_SIZE        (256 * 32),
        .MEMORY_PRIMITIVE   ("block"),
        .MEMORY_INIT_FILE   ("imem.mem"),
        .WRITE_DATA_WIDTH_A (32),
        .READ_DATA_WIDTH_A  (32),
        .BYTE_WRITE_WIDTH_A (32),
        .READ_LATENCY_A     (1),
        .WRITE_MODE_A       ("read_first")
    ) u_imem (
        .clka           (clk_i),
        .ena            (instr_req),
        .wea            (1'b0),
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
    // Drei Slaves (der Daten-Bus greift NIE aufs IMEM zu):
    //   DMEM @ 0x0001_0000..0x0001_3FFC  -> addr[31:14] == 18'h00004
    //   SEG7 @ 0x8000_0000/0x8000_0004   -> addr[31:28] == 4'h8, Reg = addr[2]
    //   UART @ 0x9000_0000               -> addr[31:28] == 4'h9, Reg = addr[3:2]
    // --------------------------------------------------------------------
    logic sel_dmem;
    logic sel_seg7;
    logic sel_uart;
    assign sel_dmem = (data_addr[31:14] == 18'h00004);
    assign sel_seg7 = (data_addr[31:28] ==  4'h8);
    assign sel_uart = (data_addr[31:28] ==  4'h9);

    logic dmem_req;
    logic seg7_req;
    logic uart_req;
    assign dmem_req = data_req & sel_dmem;
    assign seg7_req = data_req & sel_seg7;
    assign uart_req = data_req & sel_uart;

    // 1-Takt verzoegerter sel-Vektor fuer den Read-Data-Mux
    logic sel_dmem_q, sel_seg7_q, sel_uart_q;
    logic data_rvalid_q;
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            sel_dmem_q    <= 1'b0;
            sel_seg7_q    <= 1'b0;
            sel_uart_q    <= 1'b0;
            data_rvalid_q <= 1'b0;
        end else begin
            sel_dmem_q    <= dmem_req;
            sel_seg7_q    <= seg7_req;
            sel_uart_q    <= uart_req;
            data_rvalid_q <= data_req;
        end
    end

    // Slave-Ausgaben
    logic [31:0] dmem_rdata;
    logic [31:0] seg7_rdata;
    logic [31:0] uart_rdata;

    ram #(
        .DataWidth (32),
        .AddrWidth (12),
        .MemFile   ("dmem.mem")
    ) u_dmem (
        .clk_i,
        .req_i   (dmem_req),
        .we_i    (data_we),
        .be_i    (data_be),
        .addr_i  (data_addr[13:2]),
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

    uart_periph #(
        .ClkFreq  (100_000_000),
        .BaudRate (115_200)
    ) u_uart (
        .clk_i,
        .rst_ni,
        .req_i   (uart_req),
        .we_i    (data_we),
        .be_i    (data_be),
        .addr_i  (data_addr[3:2]),     // Register-Auswahl (DATA=0, STATUS=1)
        .wdata_i (data_wdata),
        .rdata_o (uart_rdata),
        .tx_o    (uart_tx_o),
        .rx_i    (uart_rx_i)
    );

    // Read-Data-Mux (1-Takt nach dem Request)
    assign data_gnt    = data_req;
    assign data_rvalid = data_rvalid_q;
    assign data_err    = 1'b0;
    assign data_rdata  = sel_dmem_q ? dmem_rdata :
                         sel_seg7_q ? seg7_rdata :
                         sel_uart_q ? uart_rdata :
                                      32'h0;

endmodule
