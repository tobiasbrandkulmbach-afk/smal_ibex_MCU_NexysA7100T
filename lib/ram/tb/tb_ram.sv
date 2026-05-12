`timescale 1ns/1ps
module tb_ram;

    // --------------------------------------------------------------------------
    // Parameters matching DUT defaults
    // --------------------------------------------------------------------------
    localparam int unsigned DW  = 32;
    localparam int unsigned AW  = 12;
    localparam int unsigned BEW = DW / 8;   // 4

    // --------------------------------------------------------------------------
    // DUT signals
    // --------------------------------------------------------------------------
    logic              clk_i   = 0;
    logic              req_i   = 0;
    logic              we_i    = 0;
    logic [BEW-1:0]    be_i    = '0;
    logic [AW-1:0]     addr_i  = '0;
    logic [DW-1:0]     wdata_i = '0;
    logic [DW-1:0]     rdata_o;

    // --------------------------------------------------------------------------
    // Clock: 10 ns period
    // --------------------------------------------------------------------------
    always #5 clk_i = ~clk_i;

    // --------------------------------------------------------------------------
    // DUT instance
    // --------------------------------------------------------------------------
    ram #(
        .DataWidth(DW),
        .AddrWidth(AW),
        .MemFile  ("")
    ) dut (
        .clk_i   (clk_i),
        .req_i   (req_i),
        .we_i    (we_i),
        .be_i    (be_i),
        .addr_i  (addr_i),
        .wdata_i (wdata_i),
        .rdata_o (rdata_o)
    );

    // --------------------------------------------------------------------------
    // Helpers
    // --------------------------------------------------------------------------
    int fail_count = 0;

    task automatic write_word(input logic [AW-1:0] addr, input logic [DW-1:0] data);
        @(negedge clk_i);
        req_i   = 1; we_i = 1; be_i = '1;
        addr_i  = addr; wdata_i = data;
        @(negedge clk_i);
        req_i   = 0; we_i = 0;
    endtask

    // Returns data in rdata_o one cycle after the task returns.
    task automatic issue_read(input logic [AW-1:0] addr);
        @(negedge clk_i);
        req_i  = 1; we_i = 0; be_i = '0;
        addr_i = addr;
        @(negedge clk_i);
        req_i  = 0;
    endtask

    task automatic check(
        input string        test_name,
        input logic [DW-1:0] got,
        input logic [DW-1:0] expected
    );
        if (got !== expected) begin
            $display("FAIL  [%s]  got=0x%08h  expected=0x%08h", test_name, got, expected);
            fail_count++;
        end else begin
            $display("ok    [%s]", test_name);
        end
    endtask

    // --------------------------------------------------------------------------
    // Test sequence
    // --------------------------------------------------------------------------
    logic [DW-1:0] rd;

    initial begin
        // Let reset settle
        repeat(2) @(negedge clk_i);

        // ------------------------------------------------------------------
        // T1: Write then read a full word
        // ------------------------------------------------------------------
        write_word(12'h001, 32'hDEAD_BEEF);
        issue_read(12'h001);
        rd = rdata_o;
        check("T1 full-word write/read", rd, 32'hDEAD_BEEF);

        // ------------------------------------------------------------------
        // T2: Different address does not alias
        // ------------------------------------------------------------------
        write_word(12'h002, 32'hCAFE_BABE);
        issue_read(12'h001);
        rd = rdata_o;
        check("T2a addr 001 unmodified", rd, 32'hDEAD_BEEF);

        issue_read(12'h002);
        rd = rdata_o;
        check("T2b addr 002 correct",    rd, 32'hCAFE_BABE);

        // ------------------------------------------------------------------
        // T3: Partial byte-enable – write only byte 0
        //     Pre-load address with 0xFFFF_FFFF first
        // ------------------------------------------------------------------
        write_word(12'h010, 32'hFFFF_FFFF);
        @(negedge clk_i);
        req_i = 1; we_i = 1; be_i = 4'b0001;   // only byte 0
        addr_i = 12'h010; wdata_i = 32'h0000_0042;
        @(negedge clk_i);
        req_i = 0; we_i = 0;

        issue_read(12'h010);
        rd = rdata_o;
        check("T3 byte-enable byte0", rd, 32'hFFFF_FF42);

        // ------------------------------------------------------------------
        // T4: Partial byte-enable – write only byte 3 (MSB)
        // ------------------------------------------------------------------
        write_word(12'h011, 32'h0000_0000);
        @(negedge clk_i);
        req_i = 1; we_i = 1; be_i = 4'b1000;   // only byte 3
        addr_i = 12'h011; wdata_i = 32'hAB00_0000;
        @(negedge clk_i);
        req_i = 0; we_i = 0;

        issue_read(12'h011);
        rd = rdata_o;
        check("T4 byte-enable byte3", rd, 32'hAB00_0000);

        // ------------------------------------------------------------------
        // T5: req_i=0 does NOT update rdata_o
        //     Write a value, read it to latch it, then toggle addr without req
        // ------------------------------------------------------------------
        write_word(12'h020, 32'h1234_5678);
        issue_read(12'h020);
        rd = rdata_o;   // should be 0x1234_5678

        // Now deassert req and change address – rdata_o must not change
        @(negedge clk_i);
        req_i = 0; addr_i = 12'h000;    // point to uninitialised loc
        @(negedge clk_i);
        check("T5 req=0 does not update rdata", rdata_o, 32'h1234_5678);

        // ------------------------------------------------------------------
        // T6: Write with be_i=0 must NOT modify memory
        //     Pre-load, attempt write with all byte-enables off, verify
        // ------------------------------------------------------------------
        write_word(12'h030, 32'hAAAA_AAAA);
        @(negedge clk_i);
        req_i = 1; we_i = 1; be_i = 4'b0000;
        addr_i = 12'h030; wdata_i = 32'h5555_5555;
        @(negedge clk_i);
        req_i = 0; we_i = 0;

        issue_read(12'h030);
        rd = rdata_o;
        check("T6 be=0 no modification", rd, 32'hAAAA_AAAA);

        // ------------------------------------------------------------------
        // T7: Sequential back-to-back writes followed by sequential reads
        // ------------------------------------------------------------------
        write_word(12'h040, 32'h0000_0001);
        write_word(12'h041, 32'h0000_0002);
        write_word(12'h042, 32'h0000_0003);

        issue_read(12'h040); rd = rdata_o;
        check("T7a seq read [040]", rd, 32'h0000_0001);
        issue_read(12'h041); rd = rdata_o;
        check("T7b seq read [041]", rd, 32'h0000_0002);
        issue_read(12'h042); rd = rdata_o;
        check("T7c seq read [042]", rd, 32'h0000_0003);

        // ------------------------------------------------------------------
        // T8: Overwrite – verify new value replaces old
        // ------------------------------------------------------------------
        write_word(12'h050, 32'h1111_1111);    // first write
        write_word(12'h050, 32'hBEEF_1234);   // overwrite
        issue_read(12'h050);
        rd = rdata_o;
        check("T8 overwrite", rd, 32'hBEEF_1234);

        // ------------------------------------------------------------------
        // Result
        // ------------------------------------------------------------------
        $display("--------------------------------------------------");
        if (fail_count == 0)
            $display("PASS – all tests passed.");
        else
            $display("FAIL – %0d test(s) failed.", fail_count);

        $finish;
    end

endmodule
