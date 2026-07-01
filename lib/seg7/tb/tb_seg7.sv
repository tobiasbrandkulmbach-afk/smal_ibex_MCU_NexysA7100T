`timescale 1ns/1ps
module tb_seg7;

    // Short slot time so the multiplexer cycles fast in simulation.
    localparam int unsigned TPD = 4;

    logic        clk_i   = 0;
    logic        rst_ni  = 0;
    logic [63:0] chars_i = '0;
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

    // Expected segment pattern (active-LOW, {DP,G,F,E,D,C,B,A}) for an ASCII
    // char with DP off. Mirrors ascii_to_segs in the DUT.
    function automatic logic [7:0] expect_segs(input logic [7:0] c);
        logic [6:0] s;
        case (c)
            "0": s = 7'b1000000; "1": s = 7'b1111001; "2": s = 7'b0100100;
            "3": s = 7'b0110000; "4": s = 7'b0011001; "5": s = 7'b0010010;
            "6": s = 7'b0000010; "7": s = 7'b1111000; "8": s = 7'b0000000;
            "9": s = 7'b0010000;
            "A","a": s = 7'b0001000; "B","b": s = 7'b0000011; "C","c": s = 7'b1000110;
            "D","d": s = 7'b0100001; "E","e": s = 7'b0000110; "F","f": s = 7'b0001110;
            "G","g": s = 7'b1000010; "H","h": s = 7'b0001001; "I","i": s = 7'b1111001;
            "J","j": s = 7'b1100001; "L","l": s = 7'b1000111; "N","n": s = 7'b0101011;
            "O","o": s = 7'b1000000; "P","p": s = 7'b0001100; "Q","q": s = 7'b0011000;
            "R","r": s = 7'b0101111; "S","s": s = 7'b0010010; "T","t": s = 7'b0000111;
            "U","u": s = 7'b1000001; "Y","y": s = 7'b0010001; "Z","z": s = 7'b0100100;
            "-": s = 7'b0111111; "_": s = 7'b1110111;
            default: s = 7'b1111111;
        endcase
        expect_segs = {1'b1, s};   // DP off (active-LOW)
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
                                    input logic [63:0] chars,
                                    input logic [7:0]  dps,
                                    input logic [7:0]  blanks);
        int    first_digit;
        int    d;
        logic [7:0] ch;
        logic [7:0] exp_seg;
        string name;

        // Sync to the start of a slot.
        @(posedge clk_i);
        while (dut.tick_cnt != 0) @(posedge clk_i);
        #1;

        first_digit = int'(dut.digit_idx);

        for (int slot = 0; slot < 8; slot++) begin
            d  = (first_digit + slot) % 8;
            ch = chars[d*8 +: 8];

            // Sample in the middle of the slot, well clear of the edge.
            tick(TPD / 2);

            name = $sformatf("%s slot%0d (digit %0d '%c')", label, slot, d, ch);

            if (blanks[d]) begin
                check_byte({name, " an "},  an_o,  8'hFF);
                check_byte({name, " seg"},  seg_o, 8'hFF);
            end else begin
                exp_seg = expect_segs(ch);
                if (dps[d]) exp_seg[7] = 1'b0;          // DP on = LOW
                check_int (name,           active_digit(), d);
                check_byte({name, " seg"}, seg_o,          exp_seg);
            end

            // Advance to the start of the next slot.
            tick(TPD - TPD / 2);
        end
    endtask

    // Pack an 8-char string (leftmost char = digit 7 = AN7) into chars_i.
    function automatic logic [63:0] pack(input logic [7:0] c7, c6, c5, c4,
                                                             c3, c2, c1, c0);
        pack = {c7, c6, c5, c4, c3, c2, c1, c0};
    endfunction

    initial begin
        // T1: Reset state – outputs blank
        tick(2);
        check_byte("T1 reset an ", an_o,  8'hFF);
        check_byte("T1 reset seg", seg_o, 8'hFF);

        rst_ni = 1;

        // T2: "HELLO123" (H on AN7 ... 3 on AN0)
        chars_i = pack("H","E","L","L","O","1","2","3");
        check_full_cycle("T2", chars_i, 8'h00, 8'h00);

        // T3: digits 0-7 straight
        chars_i = pack("0","1","2","3","4","5","6","7");
        check_full_cycle("T3", chars_i, 8'h00, 8'h00);

        // T4: mix incl. blanked/unsupported chars (space, 'X', 'K')
        chars_i = pack("A","b"," ","X","K","-","_","9");
        check_full_cycle("T4", chars_i, 8'h00, 8'h00);

        // T5: Decimal points on digits 0 and 7
        chars_i = pack("1","2","3","4","5","6","7","8");
        dp_i    = 8'b1000_0001;
        check_full_cycle("T5", chars_i, 8'b1000_0001, 8'h00);
        dp_i    = 8'h00;

        // T6: Blank middle digits
        chars_i = pack("1","2","3","4","5","6","7","8");
        blank_i = 8'b0011_1100;
        check_full_cycle("T6", chars_i, 8'h00, 8'b0011_1100);
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
