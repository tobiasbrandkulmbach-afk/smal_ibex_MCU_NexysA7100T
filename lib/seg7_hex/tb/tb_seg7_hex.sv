`timescale 1ns/1ps
module tb_seg7_hex;

    localparam int unsigned TPD = 4;

    logic        clk_i   = 0;
    logic        rst_ni  = 0;
    logic [31:0] value_i = 32'h0;
    logic [7:0]  dp_i    = 8'h0;
    logic [7:0]  blank_i = 8'h0;
    logic [7:0]  an_o;
    logic [7:0]  seg_o;

    always #5 clk_i = ~clk_i;

    seg7_hex #(.TicksPerDigit(TPD)) dut (.*);

    int fail_count = 0;

    task automatic tick(input int n = 1);
        repeat(n) @(posedge clk_i); #1;
    endtask

    // Expected segment pattern (active-LOW, {DP,G,F,E,D,C,B,A}) for a hex digit.
    function automatic logic [7:0] expect_segs(input logic [3:0] h);
        case (h)
            4'h0: expect_segs = 8'hC0; 4'h1: expect_segs = 8'hF9;
            4'h2: expect_segs = 8'hA4; 4'h3: expect_segs = 8'hB0;
            4'h4: expect_segs = 8'h99; 4'h5: expect_segs = 8'h92;
            4'h6: expect_segs = 8'h82; 4'h7: expect_segs = 8'hF8;
            4'h8: expect_segs = 8'h80; 4'h9: expect_segs = 8'h90;
            4'hA: expect_segs = 8'h88; 4'hB: expect_segs = 8'h83;
            4'hC: expect_segs = 8'hC6; 4'hD: expect_segs = 8'hA1;
            4'hE: expect_segs = 8'h86; 4'hF: expect_segs = 8'h8E;
        endcase
    endfunction

    function automatic int active_digit();
        for (int i = 0; i < 8; i++) if (an_o[i] == 1'b0) return i;
        return -1;
    endfunction

    task automatic check_byte(input string name, input logic [7:0] got, exp);
        if (got !== exp) begin
            $display("FAIL  [%s]  got=0x%02h  expected=0x%02h", name, got, exp);
            fail_count++;
        end else $display("ok    [%s]  val=0x%02h", name, got);
    endtask

    task automatic check_int(input string name, input int got, exp);
        if (got !== exp) begin
            $display("FAIL  [%s]  got=%0d  expected=%0d", name, got, exp);
            fail_count++;
        end else $display("ok    [%s]  val=%0d", name, got);
    endtask

    task automatic check_full_cycle(input string label, input logic [31:0] val);
        int first_digit, d;
        logic [3:0] nib;
        string name;

        @(posedge clk_i);
        while (dut.u_seg7.tick_cnt != 0) @(posedge clk_i);
        #1;
        first_digit = int'(dut.u_seg7.digit_idx);

        for (int slot = 0; slot < 8; slot++) begin
            d   = (first_digit + slot) % 8;
            nib = val[d*4 +: 4];
            tick(TPD / 2);
            name = $sformatf("%s slot%0d (digit %0d)", label, slot, d);
            check_int (name,           active_digit(), d);
            check_byte({name, " seg"}, seg_o,          expect_segs(nib));
            tick(TPD - TPD / 2);
        end
    endtask

    initial begin
        tick(2);
        check_byte("reset an ", an_o,  8'hFF);
        check_byte("reset seg", seg_o, 8'hFF);

        rst_ni = 1;

        value_i = 32'h0123_4567;
        check_full_cycle("T1", 32'h0123_4567);

        value_i = 32'hFEDC_BA98;
        check_full_cycle("T2", 32'hFEDC_BA98);

        $display("--------------------------------------------------");
        if (fail_count == 0) $display("PASS - all tests passed.");
        else                 $display("FAIL - %0d test(s) failed.", fail_count);
        $finish;
    end

endmodule
