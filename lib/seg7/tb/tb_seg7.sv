`timescale 1ns/1ps
module tb_seg7;

    // Short slot time so the multiplexer cycles fast in simulation.
    localparam int unsigned TPD = 4;

    logic        clk_i   = 0;
    logic        rst_ni  = 0;
    logic [31:0] value_i = 32'h0;
    logic [7:0]  dp_i    = 8'h0;
    logic [7:0]  blank_i = 8'h0;
    logic [7:0]  an_o;
    logic [7:0]  seg_o;

    always #5 clk_i = ~clk_i;

    seg7 #(.TicksPerDigit(TPD)) dut (.*);

    int fail_count = 0;

    task automatic tick(input int n = 1);
        repeat(n) @(posedge clk_i); #1;
    endtask

    // Expected segment pattern (active-LOW, {DP,G,F,E,D,C,B,A}) for a hex digit
    // with DP off.
    function automatic logic [7:0] expect_segs(input logic [3:0] h);
        case (h)
            4'h0: expect_segs = 8'hC0;
            4'h1: expect_segs = 8'hF9;
            4'h2: expect_segs = 8'hA4;
            4'h3: expect_segs = 8'hB0;
            4'h4: expect_segs = 8'h99;
            4'h5: expect_segs = 8'h92;
            4'h6: expect_segs = 8'h82;
            4'h7: expect_segs = 8'hF8;
            4'h8: expect_segs = 8'h80;
            4'h9: expect_segs = 8'h90;
            4'hA: expect_segs = 8'h88;
            4'hB: expect_segs = 8'h83;
            4'hC: expect_segs = 8'hC6;
            4'hD: expect_segs = 8'hA1;
            4'hE: expect_segs = 8'h86;
            4'hF: expect_segs = 8'h8E;
        endcase
    endfunction

    // Decode the currently active digit from an_o (one bit is 0, rest are 1).
    function automatic int active_digit();
        for (int i = 0; i < 8; i++) if (an_o[i] == 1'b0) return i;
        return -1;
    endfunction

    task automatic check_byte(input string name,
                              input logic [7:0] got,
                              input logic [7:0] exp);
        if (got !== exp) begin
            $display("FAIL  [%s]  got=0x%02h  expected=0x%02h", name, got, exp);
            fail_count++;
        end else begin
            $display("ok    [%s]  val=0x%02h", name, got);
        end
    endtask

    task automatic check_int(input string name, input int got, input int exp);
        if (got !== exp) begin
            $display("FAIL  [%s]  got=%0d  expected=%0d", name, got, exp);
            fail_count++;
        end else begin
            $display("ok    [%s]  val=%0d", name, got);
        end
    endtask

    // Walk through one full 8-digit cycle and verify each slot.
    // Syncs via dut.digit_idx (works even when the active slot is blanked).
    task automatic check_full_cycle(input string label,
                                    input logic [31:0] val,
                                    input logic [7:0]  dps,
                                    input logic [7:0]  blanks);
        int    first_digit;
        int    d;
        logic [3:0] nib;
        logic [7:0] exp_seg;
        string name;

        // Sync to the start of a slot.
        @(posedge clk_i);
        while (dut.tick_cnt != 0) @(posedge clk_i);
        #1;

        first_digit = int'(dut.digit_idx);

        for (int slot = 0; slot < 8; slot++) begin
            d   = (first_digit + slot) % 8;
            nib = val[d*4 +: 4];

            // Sample in the middle of the slot, well clear of the edge.
            tick(TPD / 2);

            name = $sformatf("%s slot%0d (digit %0d)", label, slot, d);

            if (blanks[d]) begin
                check_byte({name, " an "},  an_o,  8'hFF);
                check_byte({name, " seg"},  seg_o, 8'hFF);
            end else begin
                exp_seg = expect_segs(nib);
                if (dps[d]) exp_seg[7] = 1'b0;          // DP on = LOW
                check_int (name,           active_digit(), d);
                check_byte({name, " seg"}, seg_o,          exp_seg);
            end

            // Advance to the start of the next slot.
            tick(TPD - TPD / 2);
        end
    endtask

    initial begin
        // T1: Reset state – outputs blank
        tick(2);
        check_byte("T1 reset an ", an_o,  8'hFF);
        check_byte("T1 reset seg", seg_o, 8'hFF);

        rst_ni = 1;

        // T2: Display 0x01234567 (low nibble 7 first on AN[0])
        value_i = 32'h01234567;
        check_full_cycle("T2", 32'h01234567, 8'h00, 8'h00);

        // T3: All-A pattern exercises hex letters
        value_i = 32'hAAAA_AAAA;
        check_full_cycle("T3", 32'hAAAA_AAAA, 8'h00, 8'h00);

        // T4: Full hex coverage with 0xFEDCBA98
        value_i = 32'hFEDC_BA98;
        check_full_cycle("T4", 32'hFEDC_BA98, 8'h00, 8'h00);

        // T5: Decimal points on digits 0 and 7
        value_i = 32'h1234_5678;
        dp_i    = 8'b1000_0001;
        check_full_cycle("T5", 32'h1234_5678, 8'b1000_0001, 8'h00);
        dp_i    = 8'h00;

        // T6: Blank middle digits
        value_i = 32'h1234_5678;
        blank_i = 8'b0011_1100;
        check_full_cycle("T6", 32'h1234_5678, 8'h00, 8'b0011_1100);
        blank_i = 8'h00;

        // T7: Mid-stream reset returns to blanked state
        rst_ni = 0; tick(1);
        check_byte("T7 mid-reset an ", an_o,  8'hFF);
        check_byte("T7 mid-reset seg", seg_o, 8'hFF);
        rst_ni = 1; tick(1);

        $display("--------------------------------------------------");
        if (fail_count == 0)
            $display("PASS - all tests passed.");
        else
            $display("FAIL - %0d test(s) failed.", fail_count);

        $finish;
    end

endmodule
