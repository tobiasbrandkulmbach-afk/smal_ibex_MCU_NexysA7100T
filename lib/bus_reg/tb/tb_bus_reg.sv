`timescale 1ns/1ps
module tb_bus_reg;

    // --------------------------------------------------------------------------
    // Parameters matching DUT defaults (and exercising a non-zero reset value)
    // --------------------------------------------------------------------------
    localparam int unsigned         DW  = 32;
    localparam int unsigned         BEW = DW / 8;
    localparam logic [31:0]         RV  = 32'hCAFE_0000;

    // --------------------------------------------------------------------------
    // DUT signals
    // --------------------------------------------------------------------------
    logic              clk_i   = 0;
    logic              rst_ni  = 0;
    logic              req_i   = 0;
    logic              we_i    = 0;
    logic [BEW-1:0]    be_i    = '0;
    logic [DW-1:0]     wdata_i = '0;
    logic [DW-1:0]     rdata_o;
    logic [DW-1:0]     value_o;

    // --------------------------------------------------------------------------
    // Clock: 10 ns period
    // --------------------------------------------------------------------------
    always #5 clk_i = ~clk_i;

    // --------------------------------------------------------------------------
    // DUT instance
    // --------------------------------------------------------------------------
    bus_reg #(
        .DataWidth (DW),
        .ResetValue(RV)
    ) dut (
        .clk_i,
        .rst_ni,
        .req_i,
        .we_i,
        .be_i,
        .wdata_i,
        .rdata_o,
        .value_o
    );

    // --------------------------------------------------------------------------
    // Helpers
    // --------------------------------------------------------------------------
    int fail_count = 0;

    task automatic check(
        input string         name,
        input logic [DW-1:0] got,
        input logic [DW-1:0] exp
    );
        if (got !== exp) begin
            $display("FAIL  [%s]  got=0x%08h  expected=0x%08h", name, got, exp);
            fail_count++;
        end else begin
            $display("ok    [%s]", name);
        end
    endtask

    task automatic do_write(input logic [DW-1:0] data, input logic [BEW-1:0] mask);
        @(negedge clk_i);
        req_i = 1; we_i = 1; be_i = mask; wdata_i = data;
        @(negedge clk_i);
        req_i = 0; we_i = 0;
    endtask

    task automatic do_read(output logic [DW-1:0] data);
        @(negedge clk_i);
        req_i = 1; we_i = 0; be_i = '0;
        @(negedge clk_i);
        req_i = 0;
        data = rdata_o;
    endtask

    // --------------------------------------------------------------------------
    // Test sequence
    // --------------------------------------------------------------------------
    logic [DW-1:0] rd;

    initial begin
        // ------------------------------------------------------------------
        // T0: Reset puts value_q into the ResetValue
        // ------------------------------------------------------------------
        rst_ni = 0;
        repeat (3) @(negedge clk_i);
        check("T0a value_o = ResetValue", value_o, RV);
        check("T0b rdata_o = 0",          rdata_o, 32'h0);

        rst_ni = 1;
        @(negedge clk_i);

        // ------------------------------------------------------------------
        // T1: Full-word write, value_o updates exactly one cycle later
        // ------------------------------------------------------------------
        @(negedge clk_i);
        req_i = 1; we_i = 1; be_i = '1; wdata_i = 32'hDEAD_BEEF;
        // same cycle: still old (the write happens on the next posedge)
        check("T1a value_o still old in drive cycle", value_o, RV);
        @(negedge clk_i);
        req_i = 0; we_i = 0;
        check("T1b value_o updated 1 cycle later", value_o, 32'hDEAD_BEEF);

        // ------------------------------------------------------------------
        // T2: Bus read returns the stored value
        // ------------------------------------------------------------------
        do_read(rd);
        check("T2 rdata = stored value", rd, 32'hDEAD_BEEF);

        // ------------------------------------------------------------------
        // T3: Byte-enable - write only byte 0
        // ------------------------------------------------------------------
        do_write(32'h0000_0042, 4'b0001);
        check("T3 byte 0 updated, rest preserved", value_o, 32'hDEAD_BE42);

        // ------------------------------------------------------------------
        // T4: Byte-enable - write only byte 3 (MSB)
        // ------------------------------------------------------------------
        do_write(32'hAB00_0000, 4'b1000);
        check("T4 byte 3 updated, rest preserved", value_o, 32'hABAD_BE42);

        // ------------------------------------------------------------------
        // T5: req_i=0 means no write, even if we_i=1
        // ------------------------------------------------------------------
        @(negedge clk_i);
        req_i = 0; we_i = 1; be_i = '1; wdata_i = 32'h0000_0000;
        @(negedge clk_i);
        check("T5 req=0 blocks write", value_o, 32'hABAD_BE42);

        // ------------------------------------------------------------------
        // T6: we_i=0 means no write (read access, must not corrupt value)
        // ------------------------------------------------------------------
        @(negedge clk_i);
        req_i = 1; we_i = 0; be_i = '1; wdata_i = 32'hFFFF_FFFF;
        @(negedge clk_i);
        req_i = 0;
        check("T6 read access does not write", value_o, 32'hABAD_BE42);
        // And rdata_o should now hold the read result
        check("T6 rdata = stored value",       rdata_o, 32'hABAD_BE42);

        // ------------------------------------------------------------------
        // T7: be_i=0 with we_i=1 must NOT modify anything
        // ------------------------------------------------------------------
        do_write(32'h5555_5555, 4'b0000);
        check("T7 be=0 no modification", value_o, 32'hABAD_BE42);

        // ------------------------------------------------------------------
        // T8: Sequential writes, each visible on value_o
        // ------------------------------------------------------------------
        do_write(32'h0000_0001, 4'b1111);
        check("T8a seq 1", value_o, 32'h0000_0001);
        do_write(32'h0000_0002, 4'b1111);
        check("T8b seq 2", value_o, 32'h0000_0002);
        do_write(32'h0000_0003, 4'b1111);
        check("T8c seq 3", value_o, 32'h0000_0003);

        // ------------------------------------------------------------------
        // T9: rdata_o holds its last read between reads (no re-update)
        // ------------------------------------------------------------------
        do_read(rd);
        check("T9a rdata = 0x3", rd, 32'h0000_0003);
        // Write a new value but do NOT issue a read - rdata_o must NOT change
        do_write(32'hAAAA_BBBB, 4'b1111);
        check("T9b value updated", value_o, 32'hAAAA_BBBB);
        check("T9c rdata_o unchanged without read", rdata_o, 32'h0000_0003);

        // ------------------------------------------------------------------
        // T10: Synchronous reset restores ResetValue
        // ------------------------------------------------------------------
        @(negedge clk_i);
        rst_ni = 0;
        @(negedge clk_i);
        check("T10 reset restores ResetValue", value_o, RV);
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
