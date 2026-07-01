`timescale 1ns/1ps
module tb_seg7_periph;

    // Use TicksPerDigit=2 so one full refresh (8 digits) takes 16 clock cycles.
    localparam int unsigned TPD = 2;

    logic        clk_i  = 0;
    logic        rst_ni = 0;
    logic        req_i  = 0;
    logic        we_i   = 0;
    logic [3:0]  be_i   = '0;
    logic        addr_i = 1'b0;
    logic [31:0] wdata_i = '0;
    logic [31:0] rdata_o;
    logic [7:0]  an_o;
    logic [7:0]  seg_o;

    always #5 clk_i = ~clk_i;

    seg7_periph #(
        .TicksPerDigit(TPD)
    ) dut (
        .clk_i, .rst_ni,
        .req_i, .we_i, .be_i, .addr_i, .wdata_i,
        .rdata_o,
        .an_o, .seg_o
    );

    // Expected segment pattern (active-LOW, DP off) for an ASCII char.
    // Mirrors ascii_to_segs in lib/seg7.
    function automatic logic [7:0] expected_segs(input logic [7:0] c);
        logic [6:0] s;
        case (c)
            "0": s = 7'b1000000; "1": s = 7'b1111001; "2": s = 7'b0100100;
            "3": s = 7'b0110000; "4": s = 7'b0011001; "5": s = 7'b0010010;
            "6": s = 7'b0000010; "7": s = 7'b1111000; "8": s = 7'b0000000;
            "9": s = 7'b0010000;
            "A","a": s = 7'b0001000; "B","b": s = 7'b0000011; "C","c": s = 7'b1000110;
            "D","d": s = 7'b0100001; "E","e": s = 7'b0000110; "F","f": s = 7'b0001110;
            "H","h": s = 7'b0001001; "L","l": s = 7'b1000111; "O","o": s = 7'b1000000;
            default: s = 7'b1111111;
        endcase
        expected_segs = {1'b1, s};   // DP off (active-LOW)
    endfunction

    int fail_count = 0;

    task automatic check(input string name, input logic [31:0] got, exp);
        if (got !== exp) begin
            $display("FAIL  [%s]  got=0x%08h  expected=0x%08h", name, got, exp);
            fail_count++;
        end else begin
            $display("ok    [%s]", name);
        end
    endtask

    // Write a word to the selected register (0 = CHARS_LO, 1 = CHARS_HI).
    task automatic bus_write(input logic sel, input logic [31:0] data,
                             input logic [3:0] mask);
        @(negedge clk_i);
        req_i = 1; we_i = 1; be_i = mask; addr_i = sel; wdata_i = data;
        @(negedge clk_i);
        req_i = 0; we_i = 0;
    endtask

    // Wait until seg7 multiplexes to digit idx, return captured seg_o.
    task automatic wait_digit(input logic [2:0] idx, output logic [7:0] seg_cap);
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

    logic [7:0]  seg_cap;
    logic [63:0] shown;   // expected 8 chars, digit0 in [7:0]

    initial begin
        // T0: during reset all anodes/segments inactive
        rst_ni = 0;
        repeat (4) @(negedge clk_i);
        check("T0 an_o during reset",  {24'h0, an_o},  32'hFF);
        check("T0 seg_o during reset", {24'h0, seg_o}, 32'hFF);

        rst_ni = 1;
        @(negedge clk_i);

        // T1: after reset both registers = 0 → every digit shows '0' (0x00 → blank
        //     actually: byte 0x00 is unsupported → blank). Check digit 0 blank.
        wait_digit(3'h0, seg_cap);
        check("T1 digit 0 blank (0x00)", {24'h0, seg_cap}, 32'hFF);

        // T2: write "HELO" to CHARS_LO and "1234" to CHARS_HI.
        //     CHARS_LO: digit0='H',1='E',2='L',3='O'  -> word {O,L,E,H}
        //     CHARS_HI: digit4='1',5='2',6='3',7='4'  -> word {4,3,2,1}
        bus_write(1'b0, {"O","L","E","H"}, 4'b1111);
        bus_write(1'b1, {"4","3","2","1"}, 4'b1111);
        @(negedge clk_i);

        shown = {"4","3","2","1","O","L","E","H"};   // digit7..digit0
        begin : check_all
            for (int d = 0; d < 8; d++) begin
                automatic logic [7:0] ch = shown[d*8 +: 8];
                wait_digit(3'(d), seg_cap);
                check($sformatf("T2 digit %0d '%c'", d, ch),
                      {24'h0, seg_cap}, {24'h0, expected_segs(ch)});
            end
        end

        // T3: read back both registers (1-cycle latency)
        @(negedge clk_i);
        req_i = 1; we_i = 0; addr_i = 1'b0; be_i = '0;   // read CHARS_LO
        @(negedge clk_i);
        req_i = 0;
        @(negedge clk_i);
        check("T3 CHARS_LO readback", rdata_o, {"O","L","E","H"});

        @(negedge clk_i);
        req_i = 1; we_i = 0; addr_i = 1'b1; be_i = '0;   // read CHARS_HI
        @(negedge clk_i);
        req_i = 0;
        @(negedge clk_i);
        check("T3 CHARS_HI readback", rdata_o, {"4","3","2","1"});

        // T4: byte-enable write - change only digit0 of CHARS_LO to 'A'
        bus_write(1'b0, {24'h0, "A"}, 4'b0001);
        @(negedge clk_i);
        wait_digit(3'h0, seg_cap);
        check("T4 digit0 now 'A'", {24'h0, seg_cap}, {24'h0, expected_segs("A")});
        wait_digit(3'h3, seg_cap);
        check("T4 digit3 unchanged 'O'", {24'h0, seg_cap}, {24'h0, expected_segs("O")});

        // T5: no write without req_i
        @(negedge clk_i);
        req_i = 0; we_i = 1; be_i = '1; addr_i = 1'b1; wdata_i = 32'hFFFF_FFFF;
        @(negedge clk_i);
        wait_digit(3'h7, seg_cap);
        check("T5 digit7 unchanged '4'", {24'h0, seg_cap}, {24'h0, expected_segs("4")});
        req_i = 0; we_i = 0;

        $display("--------------------------------------------------");
        if (fail_count == 0)
            $display("PASS - all tests passed.");
        else
            $display("FAIL - %0d test(s) failed.", fail_count);

        $finish;
    end

endmodule
