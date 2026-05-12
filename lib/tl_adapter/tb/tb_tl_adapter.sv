`timescale 1ns/1ps
module tb_tl_adapter
    import tlul_pkg::*;
;

    // ------------------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------------------
    localparam int unsigned AW = 12;          // RAM word-address width
    localparam int unsigned DW = TL_DW;       // 32

    // ------------------------------------------------------------------------
    // Clock / reset
    // ------------------------------------------------------------------------
    logic clk_i  = 0;
    logic rst_ni = 0;
    always #5 clk_i = ~clk_i;

    // ------------------------------------------------------------------------
    // DUT signals
    // ------------------------------------------------------------------------
    tl_h2d_t h2d;
    tl_d2h_t d2h;

    logic              ram_req;
    logic              ram_we;
    logic [TL_DBW-1:0] ram_be;
    logic [AW-1:0]     ram_addr;
    logic [DW-1:0]     ram_wdata;
    logic [DW-1:0]     ram_rdata;

    tl_adapter #(
        .AddrWidth(AW)
    ) dut (
        .clk_i,
        .rst_ni,
        .tl_h2d_i (h2d),
        .tl_d2h_o (d2h),
        .req_o    (ram_req),
        .we_o     (ram_we),
        .be_o     (ram_be),
        .addr_o   (ram_addr),
        .wdata_o  (ram_wdata),
        .rdata_i  (ram_rdata)
    );

    ram #(
        .DataWidth(DW),
        .AddrWidth(AW)
    ) u_ram (
        .clk_i,
        .req_i   (ram_req),
        .we_i    (ram_we),
        .be_i    (ram_be),
        .addr_i  (ram_addr),
        .wdata_i (ram_wdata),
        .rdata_o (ram_rdata)
    );

    // ------------------------------------------------------------------------
    // Score-keeping
    // ------------------------------------------------------------------------
    int fail_count = 0;

    task automatic check_eq32(input string name, input logic [31:0] got, input logic [31:0] exp);
        if (got !== exp) begin
            $display("FAIL  [%s]  got=0x%08h  expected=0x%08h", name, got, exp);
            fail_count++;
        end else begin
            $display("ok    [%s]", name);
        end
    endtask

    task automatic check_eq8(input string name, input logic [7:0] got, input logic [7:0] exp);
        if (got !== exp) begin
            $display("FAIL  [%s]  got=0x%02h  expected=0x%02h", name, got, exp);
            fail_count++;
        end else begin
            $display("ok    [%s]", name);
        end
    endtask

    task automatic check_true(input string name, input logic v);
        if (v !== 1'b1) begin
            $display("FAIL  [%s]  expected 1, got %0b", name, v);
            fail_count++;
        end else begin
            $display("ok    [%s]", name);
        end
    endtask

    task automatic check_false(input string name, input logic v);
        if (v !== 1'b0) begin
            $display("FAIL  [%s]  expected 0, got %0b", name, v);
            fail_count++;
        end else begin
            $display("ok    [%s]", name);
        end
    endtask

    // ------------------------------------------------------------------------
    // TL-UL drivers
    // ------------------------------------------------------------------------
    // Wait until a_ready, then accept on the next posedge.
    task automatic tl_send_a(
        input tl_a_op_e         op,
        input logic [TL_AW-1:0] addr,
        input logic [TL_DBW-1:0] mask,
        input logic [TL_DW-1:0]  data,
        input logic [TL_AIW-1:0] source
    );
        @(negedge clk_i);
        h2d.a_valid   = 1'b1;
        h2d.a_opcode  = op;
        h2d.a_param   = 3'h0;
        h2d.a_size    = 2'h2;          // 4 bytes
        h2d.a_source  = source;
        h2d.a_address = addr;
        h2d.a_mask    = mask;
        h2d.a_data    = data;
        h2d.a_user    = '0;
        // a_ready is combinational; wait until it is asserted at a negedge.
        while (!d2h.a_ready) @(negedge clk_i);
        // Next posedge consumes the request.
        @(posedge clk_i);
        h2d.a_valid = 1'b0;
    endtask

    // Wait for d_valid and return payload. d_ready is held high so the
    // response is consumed on the same posedge it appears.
    task automatic tl_recv_d(
        output tl_d_op_e         op,
        output logic [TL_AIW-1:0] source,
        output logic [TL_DW-1:0]  data,
        output logic              err
    );
        // d_valid becomes high one cycle after acceptance. Just after the
        // last posedge in tl_send_a, req_pending becomes 1 → d_valid = 1.
        while (!d2h.d_valid) @(posedge clk_i);
        op     = d2h.d_opcode;
        source = d2h.d_source;
        data   = d2h.d_data;
        err    = d2h.d_error;
        // The response is consumed on this posedge (d_ready=1, d_valid=1).
        @(negedge clk_i);
    endtask

    task automatic tl_write(input logic [TL_AW-1:0] byte_addr, input logic [31:0] data,
                            input logic [TL_DBW-1:0] mask = 4'b1111,
                            input string label = "write");
        tl_d_op_e         op;
        logic [TL_AIW-1:0] src;
        logic [TL_DW-1:0]  d;
        logic              err;
        tl_a_op_e          a_op;

        a_op = (mask == 4'b1111) ? PutFullData : PutPartialData;
        tl_send_a(a_op, byte_addr, mask, data, 8'hAB);
        tl_recv_d(op, src, d, err);

        if (op !== AccessAck) begin
            $display("FAIL  [%s] d_opcode = %0d, expected AccessAck", label, op);
            fail_count++;
        end
        check_eq8 ({label, " source"}, src, 8'hAB);
        check_false({label, " no error"}, err);
    endtask

    task automatic tl_read(input logic [TL_AW-1:0] byte_addr, input logic [31:0] expected,
                           input string label = "read");
        tl_d_op_e         op;
        logic [TL_AIW-1:0] src;
        logic [TL_DW-1:0]  d;
        logic              err;

        tl_send_a(Get, byte_addr, 4'b1111, 32'h0, 8'hCD);
        tl_recv_d(op, src, d, err);

        if (op !== AccessAckData) begin
            $display("FAIL  [%s] d_opcode = %0d, expected AccessAckData", label, op);
            fail_count++;
        end
        check_eq8 ({label, " source"}, src, 8'hCD);
        check_eq32({label, " data"},   d,   expected);
        check_false({label, " no error"}, err);
    endtask

    // ------------------------------------------------------------------------
    // Tests
    // ------------------------------------------------------------------------
    tl_d_op_e         rop;
    logic [TL_AIW-1:0] rsrc;
    logic [TL_DW-1:0]  rdat;
    logic              rerr;

    initial begin
        // Initial idle: bus quiescent, d_ready=1 always
        h2d = '0;
        h2d.d_ready = 1'b1;

        // Reset
        rst_ni = 0;
        repeat (3) @(negedge clk_i);
        rst_ni = 1;
        @(negedge clk_i);

        // ------------------------------------------------------------------
        // T1: PutFullData @ word 0, then Get @ word 0
        // Byte address 0x00000000 → word index 0
        // ------------------------------------------------------------------
        tl_write(32'h0000_0000, 32'hDEAD_BEEF, 4'b1111, "T1 write w0");
        tl_read (32'h0000_0000, 32'hDEAD_BEEF,          "T1 read  w0");

        // ------------------------------------------------------------------
        // T2: Different word, verify no aliasing
        // Byte address 0x00000004 → word index 1
        // ------------------------------------------------------------------
        tl_write(32'h0000_0004, 32'hCAFE_BABE, 4'b1111, "T2 write w1");
        tl_read (32'h0000_0000, 32'hDEAD_BEEF,          "T2 read  w0 unchanged");
        tl_read (32'h0000_0004, 32'hCAFE_BABE,          "T2 read  w1");

        // ------------------------------------------------------------------
        // T3: PutPartialData — byte-enable byte 0 only
        // ------------------------------------------------------------------
        tl_write(32'h0000_0040, 32'hFFFF_FFFF, 4'b1111, "T3 pre  w16");
        tl_write(32'h0000_0040, 32'h0000_0042, 4'b0001, "T3 byte0 w16");
        tl_read (32'h0000_0040, 32'hFFFF_FF42,          "T3 read  w16");

        // ------------------------------------------------------------------
        // T4: PutPartialData — byte-enable byte 3 only (MSB)
        // ------------------------------------------------------------------
        tl_write(32'h0000_0044, 32'h0000_0000, 4'b1111, "T4 pre  w17");
        tl_write(32'h0000_0044, 32'hAB00_0000, 4'b1000, "T4 byte3 w17");
        tl_read (32'h0000_0044, 32'hAB00_0000,          "T4 read  w17");

        // ------------------------------------------------------------------
        // T5: Higher byte-address bits are ignored (no base subtraction here)
        //   Byte addr 0x00000008 and 0xDEAD0008 both target word 2
        // ------------------------------------------------------------------
        tl_write(32'h0000_0008, 32'h1234_5678, 4'b1111, "T5 write w2 low base");
        tl_read (32'hDEAD_0008, 32'h1234_5678,          "T5 read  w2 high base");

        // ------------------------------------------------------------------
        // T6: Unknown opcode → d_error, peripheral must NOT see req
        // ------------------------------------------------------------------
        @(negedge clk_i);
        h2d.a_valid   = 1'b1;
        h2d.a_opcode  = tl_a_op_e'(3'h7);   // not in {Get, Put*}
        h2d.a_param   = 3'h0;
        h2d.a_size    = 2'h2;
        h2d.a_source  = 8'hEE;
        h2d.a_address = 32'h0000_0000;
        h2d.a_mask    = '1;
        h2d.a_data    = 32'h0;
        h2d.a_user    = '0;
        while (!d2h.a_ready) @(negedge clk_i);
        // Just before the accept-posedge: req_o must be 0 (bad opcode).
        check_false("T6 req_o suppressed on bad opcode", ram_req);
        @(posedge clk_i);
        h2d.a_valid = 1'b0;

        while (!d2h.d_valid) @(posedge clk_i);
        check_true ("T6 d_error asserted", d2h.d_error);
        check_eq8  ("T6 d_source mirrored", d2h.d_source, 8'hEE);
        @(negedge clk_i);

        // ------------------------------------------------------------------
        // T7: a_ready de-asserts while transaction in flight, re-asserts after
        // ------------------------------------------------------------------
        check_true ("T7 a_ready high in idle", d2h.a_ready);
        @(negedge clk_i);
        h2d.a_valid   = 1'b1;
        h2d.a_opcode  = Get;
        h2d.a_param   = 3'h0;
        h2d.a_size    = 2'h2;
        h2d.a_source  = 8'h11;
        h2d.a_address = 32'h0000_0000;
        h2d.a_mask    = '1;
        h2d.a_data    = '0;
        h2d.a_user    = '0;
        @(posedge clk_i);     // request accepted
        h2d.a_valid = 0;
        @(negedge clk_i);
        check_false("T7 a_ready low while pending", d2h.a_ready);
        check_true ("T7 d_valid high in response cycle", d2h.d_valid);

        // Let response complete
        @(posedge clk_i);
        @(negedge clk_i);
        check_true ("T7 a_ready returns high", d2h.a_ready);
        check_false("T7 d_valid drops",        d2h.d_valid);

        // ------------------------------------------------------------------
        // T8: Back-to-back writes via the wrapper task (covers steady state)
        // ------------------------------------------------------------------
        tl_write(32'h0000_0080, 32'h1111_1111, 4'b1111, "T8a w32");
        tl_write(32'h0000_0084, 32'h2222_2222, 4'b1111, "T8b w33");
        tl_write(32'h0000_0088, 32'h3333_3333, 4'b1111, "T8c w34");
        tl_read (32'h0000_0080, 32'h1111_1111,          "T8d r32");
        tl_read (32'h0000_0084, 32'h2222_2222,          "T8e r33");
        tl_read (32'h0000_0088, 32'h3333_3333,          "T8f r34");

        // ------------------------------------------------------------------
        // T9: d_ready back-pressure — host stalls one cycle, adapter must hold
        // ------------------------------------------------------------------
        // Pre-load a known value
        tl_write(32'h0000_00C0, 32'hA5A5_A5A5, 4'b1111, "T9 pre");

        // Issue read with d_ready=0 initially
        @(negedge clk_i);
        h2d.d_ready = 0;
        h2d.a_valid   = 1;
        h2d.a_opcode  = Get;
        h2d.a_param   = 3'h0;
        h2d.a_size    = 2'h2;
        h2d.a_source  = 8'h99;
        h2d.a_address = 32'h0000_00C0;
        h2d.a_mask    = '1;
        h2d.a_data    = '0;
        h2d.a_user    = '0;
        @(posedge clk_i);
        h2d.a_valid = 0;

        @(negedge clk_i);
        check_true ("T9 d_valid asserted while d_ready=0", d2h.d_valid);
        check_eq32 ("T9 d_data held under back-pressure", d2h.d_data, 32'hA5A5_A5A5);

        @(negedge clk_i);
        check_true ("T9 d_valid still high (2nd cycle stall)", d2h.d_valid);
        check_eq32 ("T9 d_data still held (2nd cycle stall)", d2h.d_data, 32'hA5A5_A5A5);

        // Release back-pressure
        h2d.d_ready = 1;
        @(posedge clk_i);    // response consumed
        @(negedge clk_i);
        check_false("T9 d_valid drops after d_ready", d2h.d_valid);

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
