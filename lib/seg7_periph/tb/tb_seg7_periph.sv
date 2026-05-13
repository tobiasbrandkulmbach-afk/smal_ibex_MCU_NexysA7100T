`timescale 1ns/1ps
module tb_seg7_periph;

    // Use TicksPerDigit=2 so one full refresh (8 digits) takes 16 clock cycles.
    localparam int unsigned TPD = 2;

    logic        clk_i  = 0;
    logic        rst_ni = 0;
    logic        req_i  = 0;
    logic        we_i   = 0;
    logic [3:0]  be_i   = '0;
    logic [31:0] wdata_i = '0;
    logic [31:0] rdata_o;
    logic [7:0]  an_o;
    logic [7:0]  seg_o;

    always #5 clk_i = ~clk_i;

    seg7_periph #(
        .TicksPerDigit(TPD)
    ) dut (
        .clk_i, .rst_ni,
        .req_i, .we_i, .be_i, .wdata_i,
        .rdata_o,
        .an_o, .seg_o
    );

    // -----------------------------------------------------------------------
    // Expected segment patterns for hex_to_segs (g,f,e,d,c,b,a active-LOW)
    // -----------------------------------------------------------------------
    function automatic logic [6:0] expected_segs(input logic [3:0] h);
        case (h)
            4'h0: expected_segs = 7'b1000000;
            4'h1: expected_segs = 7'b1111001;
            4'h2: expected_segs = 7'b0100100;
            4'h3: expected_segs = 7'b0110000;
            4'h4: expected_segs = 7'b0011001;
            4'h5: expected_segs = 7'b0010010;
            4'h6: expected_segs = 7'b0000010;
            4'h7: expected_segs = 7'b1111000;
            4'h8: expected_segs = 7'b0000000;
            4'h9: expected_segs = 7'b0010000;
            4'hA: expected_segs = 7'b0001000;
            4'hB: expected_segs = 7'b0000011;
            4'hC: expected_segs = 7'b1000110;
            4'hD: expected_segs = 7'b0100001;
            4'hE: expected_segs = 7'b0000110;
            4'hF: expected_segs = 7'b0001110;
            default: expected_segs = 7'b1111111;
        endcase
    endfunction

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------
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

    // Write a word to the peripheral
    task automatic bus_write(input logic [31:0] data, input logic [3:0] mask);
        @(negedge clk_i);
        req_i = 1; we_i = 1; be_i = mask; wdata_i = data;
        @(negedge clk_i);
        req_i = 0; we_i = 0;
    endtask

    // Wait for seg7 to multiplex to digit idx (one-hot ~AN matches)
    // Returns seg_o captured for that digit.
    task automatic wait_digit(
        input  logic [2:0]  idx,
        output logic [7:0]  seg_cap
    );
        logic [7:0] expected_an = ~(8'b1 << idx);
        int timeout = 8 * TPD * 4;
        while (an_o !== expected_an && timeout > 0) begin
            @(posedge clk_i); timeout--;
        end
        if (timeout == 0) begin
            $display("FAIL  [wait_digit %0d] timed out, an_o=0x%02h", idx, an_o);
            fail_count++;
        end
        seg_cap = seg_o;
    endtask

    // -----------------------------------------------------------------------
    // Test sequence
    // -----------------------------------------------------------------------
    logic [7:0]  seg_cap;
    logic [31:0] val;

    initial begin
        // ------------------------------------------------------------------
        // T0: During reset all anodes and segments must be inactive (0xFF)
        // ------------------------------------------------------------------
        rst_ni = 0;
        repeat (4) @(negedge clk_i);
        check("T0 an_o during reset",  {24'h0, an_o},  32'hFF);
        check("T0 seg_o during reset", {24'h0, seg_o}, 32'hFF);

        rst_ni = 1;
        @(negedge clk_i);

        // ------------------------------------------------------------------
        // T1: After reset register = 0 → all digits show '0'
        // ------------------------------------------------------------------
        wait_digit(3'h0, seg_cap);
        check("T1 digit 0 shows 0x0", {24'h0, seg_cap}, {24'h0, 8'({1'b1, expected_segs(4'h0)})});

        // ------------------------------------------------------------------
        // T2: Write 0xDEAD_BEEF → verify all 8 digits via multiplexer
        // ------------------------------------------------------------------
        bus_write(32'hDEAD_BEEF, 4'b1111);

        // value registered after 1 cycle; wait one extra clock
        @(negedge clk_i);

        begin : check_all_digits
            val = 32'hDEAD_BEEF;
            for (int d = 0; d < 8; d++) begin
                automatic logic [3:0] nibble = val[d*4 +: 4];
                automatic string      name;
                name = $sformatf("T2 digit %0d (nibble %h)", d, nibble);
                wait_digit(3'(d), seg_cap);
                check(name, {24'h0, seg_cap}, {24'h0, 8'({1'b1, expected_segs(nibble)})});
            end
        end

        // ------------------------------------------------------------------
        // T3: rdata_o returns stored value (1-cycle latency)
        // ------------------------------------------------------------------
        @(negedge clk_i);
        req_i = 1; we_i = 0; be_i = '0;  // read access
        @(negedge clk_i);
        req_i = 0;
        @(negedge clk_i);                 // one more cycle for rdata to update
        check("T3 rdata_o = 0xDEAD_BEEF", rdata_o, 32'hDEAD_BEEF);

        // ------------------------------------------------------------------
        // T4: Byte-enable write (only byte 0) → low byte updated, rest kept
        // ------------------------------------------------------------------
        bus_write(32'h0000_0042, 4'b0001);
        @(negedge clk_i);
        wait_digit(3'h0, seg_cap);   // rightmost nibble (bits 3:0 = 0x2)
        check("T4 digit 0 updated to 0x2", {24'h0, seg_cap}, {24'h0, 8'({1'b1, expected_segs(4'h2)})});
        wait_digit(3'h7, seg_cap);   // leftmost nibble (bits 31:28 = 0xD, unchanged)
        check("T4 digit 7 unchanged (0xD)", {24'h0, seg_cap}, {24'h0, 8'({1'b1, expected_segs(4'hD)})});

        // ------------------------------------------------------------------
        // T5: No write without req_i
        // ------------------------------------------------------------------
        @(negedge clk_i);
        req_i = 0; we_i = 1; be_i = '1; wdata_i = 32'hFFFF_FFFF;
        @(negedge clk_i);
        wait_digit(3'h7, seg_cap);
        check("T5 no write without req_i, digit 7 = 0xD", {24'h0, seg_cap}, {24'h0, 8'({1'b1, expected_segs(4'hD)})});
        req_i = 0; we_i = 0;

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
