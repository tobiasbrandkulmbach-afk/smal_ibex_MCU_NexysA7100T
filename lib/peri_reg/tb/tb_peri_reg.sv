`timescale 1ns/1ps
module tb_peri_reg;

    // --------------------------------------------------------------------------
    // Constants
    // --------------------------------------------------------------------------
    localparam logic [31:0] RV_RW = 32'hCAFE_0000;
    localparam logic [31:0] RV_RO = 32'h0000_0000;

    // --------------------------------------------------------------------------
    // Common clock / reset
    // --------------------------------------------------------------------------
    logic clk_i  = 0;
    logic rst_ni = 0;
    always #5 clk_i = ~clk_i;

    // --------------------------------------------------------------------------
    // DUT 1: RW register
    // --------------------------------------------------------------------------
    logic        rw_we_i    = 0;
    logic [3:0]  rw_be_i    = '0;
    logic [31:0] rw_wdata_i = '0;
    logic [31:0] rw_rdata_o;
    logic [31:0] rw_hw_i    = 32'hDEAD_DEAD;   // must be ignored in RW mode
    logic [31:0] rw_q_o;

    peri_reg #(
        .RESET_VAL(RV_RW),
        .READ_ONLY(1'b0)
    ) dut_rw (
        .clk_i,
        .rst_ni,
        .we_i   (rw_we_i),
        .be_i   (rw_be_i),
        .wdata_i(rw_wdata_i),
        .rdata_o(rw_rdata_o),
        .hw_i   (rw_hw_i),
        .q_o    (rw_q_o)
    );

    // --------------------------------------------------------------------------
    // DUT 2: READ_ONLY register (hw_i drives storage every cycle)
    // --------------------------------------------------------------------------
    logic [31:0] ro_wdata_i = 32'hBAD0_BAD0;   // must be ignored
    logic [31:0] ro_rdata_o;
    logic [31:0] ro_hw_i    = 32'h0000_0000;
    logic [31:0] ro_q_o;

    peri_reg #(
        .RESET_VAL(RV_RO),
        .READ_ONLY(1'b1)
    ) dut_ro (
        .clk_i,
        .rst_ni,
        .we_i   (1'b1),                         // even with we_i high, must not write
        .be_i   (4'b1111),
        .wdata_i(ro_wdata_i),
        .rdata_o(ro_rdata_o),
        .hw_i   (ro_hw_i),
        .q_o    (ro_q_o)
    );

    // --------------------------------------------------------------------------
    // Helpers
    // --------------------------------------------------------------------------
    int fail_count = 0;

    task automatic check(
        input string         name,
        input logic [31:0]   got,
        input logic [31:0]   exp
    );
        if (got !== exp) begin
            $display("FAIL  [%s]  got=0x%08h  expected=0x%08h", name, got, exp);
            fail_count++;
        end else begin
            $display("ok    [%s]", name);
        end
    endtask

    task automatic rw_write(input logic [31:0] data, input logic [3:0] mask);
        @(negedge clk_i);
        rw_we_i = 1; rw_be_i = mask; rw_wdata_i = data;
        @(negedge clk_i);
        rw_we_i = 0;
    endtask

    // --------------------------------------------------------------------------
    // Test sequence
    // --------------------------------------------------------------------------
    initial begin
        // ------------------------------------------------------------------
        // Reset
        // ------------------------------------------------------------------
        rst_ni = 0;
        repeat (3) @(negedge clk_i);
        check("T0a RW q_o = RESET_VAL",       rw_q_o, RV_RW);
        check("T0b RW rdata_o = 0 after rst", rw_rdata_o, 32'h0);
        check("T0c RO q_o = RESET_VAL",       ro_q_o, RV_RO);

        rst_ni = 1;
        @(negedge clk_i);

        // ------------------------------------------------------------------
        // T1: RW full-word write, q_o updates one cycle later
        // ------------------------------------------------------------------
        @(negedge clk_i);
        rw_we_i = 1; rw_be_i = '1; rw_wdata_i = 32'hDEAD_BEEF;
        check("T1a q_o still old in drive cycle", rw_q_o, RV_RW);
        @(negedge clk_i);
        rw_we_i = 0;
        check("T1b q_o updated 1 cycle later", rw_q_o, 32'hDEAD_BEEF);

        // ------------------------------------------------------------------
        // T2: rdata_o tracks storage with 1-cycle latency
        // ------------------------------------------------------------------
        @(negedge clk_i);
        check("T2 rdata_o catches up to storage", rw_rdata_o, 32'hDEAD_BEEF);

        // ------------------------------------------------------------------
        // T3: Byte-enable - write only byte 0
        // ------------------------------------------------------------------
        rw_write(32'h0000_0042, 4'b0001);
        check("T3 byte 0 updated, rest preserved", rw_q_o, 32'hDEAD_BE42);

        // ------------------------------------------------------------------
        // T4: Byte-enable - write only byte 3 (MSB)
        // ------------------------------------------------------------------
        rw_write(32'hAB00_0000, 4'b1000);
        check("T4 byte 3 updated, rest preserved", rw_q_o, 32'hABAD_BE42);

        // ------------------------------------------------------------------
        // T5: we_i=0 must not modify storage
        // ------------------------------------------------------------------
        @(negedge clk_i);
        rw_we_i = 0; rw_be_i = '1; rw_wdata_i = 32'hFFFF_FFFF;
        @(negedge clk_i);
        check("T5 we=0 blocks write", rw_q_o, 32'hABAD_BE42);

        // ------------------------------------------------------------------
        // T6: be_i=0 with we_i=1 must not modify storage
        // ------------------------------------------------------------------
        rw_write(32'h5555_5555, 4'b0000);
        check("T6 be=0 no modification", rw_q_o, 32'hABAD_BE42);

        // ------------------------------------------------------------------
        // T7: hw_i is ignored in RW mode
        // ------------------------------------------------------------------
        rw_hw_i = 32'hAAAA_5555;
        repeat (3) @(negedge clk_i);
        check("T7 hw_i ignored in RW mode", rw_q_o, 32'hABAD_BE42);

        // ------------------------------------------------------------------
        // T8: Sequential writes
        // ------------------------------------------------------------------
        rw_write(32'h0000_0001, 4'b1111);
        check("T8a seq 1", rw_q_o, 32'h0000_0001);
        rw_write(32'h0000_0002, 4'b1111);
        check("T8b seq 2", rw_q_o, 32'h0000_0002);
        rw_write(32'h0000_0003, 4'b1111);
        check("T8c seq 3", rw_q_o, 32'h0000_0003);

        // ------------------------------------------------------------------
        // T9: READ_ONLY - hw_i drives storage, bus writes ignored
        // ------------------------------------------------------------------
        @(negedge clk_i);
        ro_hw_i = 32'h1234_5678;
        @(negedge clk_i);
        check("T9a RO q_o follows hw_i", ro_q_o, 32'h1234_5678);
        @(negedge clk_i);
        check("T9b RO rdata_o tracks storage", ro_rdata_o, 32'h1234_5678);

        ro_hw_i = 32'hF00D_F00D;
        @(negedge clk_i);
        check("T9c RO q_o follows updated hw_i", ro_q_o, 32'hF00D_F00D);

        @(negedge clk_i);
        check("T9d RO bus write blocked", ro_q_o, 32'hF00D_F00D);

        // ------------------------------------------------------------------
        // T10: Synchronous reset restores RESET_VAL
        // ------------------------------------------------------------------
        @(negedge clk_i);
        rst_ni = 0;
        @(negedge clk_i);
        check("T10a reset restores RW RESET_VAL", rw_q_o, RV_RW);
        check("T10b reset restores RO RESET_VAL", ro_q_o, RV_RO);
        rst_ni = 1;
        @(negedge clk_i);

        // ------------------------------------------------------------------
        // Result
        // ------------------------------------------------------------------
        $display("--------------------------------------------------");
        if (fail_count == 0)
            $display("PASS - all tests passed.");
        else
            $display("FAIL - %0d test(s) failed.", fail_count);

        $finish;
    end

endmodule
