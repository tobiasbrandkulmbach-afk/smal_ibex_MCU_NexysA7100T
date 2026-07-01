// 8-digit character 7-segment controller for Nexys A7 (common-anode, active-LOW).
// Displays 8 ASCII characters (one byte per digit) via a built-in font.
//   chars_i[7:0]    → digit 0 (rightmost, AN[0])
//   chars_i[63:56]  → digit 7 (leftmost,  AN[7])
// Time-multiplexes through all 8 digits: each digit is lit for TicksPerDigit
// clock cycles. Default 100_000 → 1 ms per digit at 100 MHz (125 Hz full
// refresh, ~1 kHz per digit slot per docs/README.md).
// Segment mapping seg_o[7:0] = {DP, G, F, E, D, C, B, A}, active-LOW.
//
// The font renders 0-9 and the letters that are legible on a 7-segment digit
// (A b C d E F G H I J L n o P q r S t U y, plus Z as "2"). Upper/lower case
// map to the same glyph. Characters that cannot be shown (K M V W X, space,
// control chars, unknown) are blanked.
module seg7 #(
    parameter int unsigned TicksPerDigit = 100_000
) (
    input  logic        clk_i,
    input  logic        rst_ni,         // active-low synchronous reset

    input  logic [63:0] chars_i,        // 8 ASCII bytes, one per digit
    input  logic [7:0]  dp_i,           // decimal points, 1 = on, per digit
    input  logic [7:0]  blank_i,        // blank digits, 1 = off, per digit

    output logic [7:0]  an_o,           // anode select, active-LOW (AN[7:0])
    output logic [7:0]  seg_o           // {DP,G,F,E,D,C,B,A}, active-LOW
);

    localparam int unsigned CntW = (TicksPerDigit <= 1) ? 1 : $clog2(TicksPerDigit);

    logic [CntW-1:0] tick_cnt;
    logic [2:0]      digit_idx;

    // Clock divider + digit rotator
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            tick_cnt  <= '0;
            digit_idx <= '0;
        end else if (tick_cnt == CntW'(TicksPerDigit - 1)) begin
            tick_cnt  <= '0;
            digit_idx <= digit_idx + 3'd1;     // wraps 7 → 0
        end else begin
            tick_cnt <= tick_cnt + 1'b1;
        end
    end

    // ASCII byte → 7 segments (g,f,e,d,c,b,a), active-LOW (0 = segment on).
    function automatic logic [6:0] ascii_to_segs(input logic [7:0] c);
        case (c)
            // digits
            "0": ascii_to_segs = 7'b1000000;
            "1": ascii_to_segs = 7'b1111001;
            "2": ascii_to_segs = 7'b0100100;
            "3": ascii_to_segs = 7'b0110000;
            "4": ascii_to_segs = 7'b0011001;
            "5": ascii_to_segs = 7'b0010010;
            "6": ascii_to_segs = 7'b0000010;
            "7": ascii_to_segs = 7'b1111000;
            "8": ascii_to_segs = 7'b0000000;
            "9": ascii_to_segs = 7'b0010000;
            // letters (upper/lower map to the same glyph)
            "A", "a": ascii_to_segs = 7'b0001000;
            "B", "b": ascii_to_segs = 7'b0000011;
            "C", "c": ascii_to_segs = 7'b1000110;
            "D", "d": ascii_to_segs = 7'b0100001;
            "E", "e": ascii_to_segs = 7'b0000110;
            "F", "f": ascii_to_segs = 7'b0001110;
            "G", "g": ascii_to_segs = 7'b1000010;
            "H", "h": ascii_to_segs = 7'b0001001;
            "I", "i": ascii_to_segs = 7'b1111001;
            "J", "j": ascii_to_segs = 7'b1100001;
            "L", "l": ascii_to_segs = 7'b1000111;
            "N", "n": ascii_to_segs = 7'b0101011;
            "O", "o": ascii_to_segs = 7'b1000000;
            "P", "p": ascii_to_segs = 7'b0001100;
            "Q", "q": ascii_to_segs = 7'b0011000;
            "R", "r": ascii_to_segs = 7'b0101111;
            "S", "s": ascii_to_segs = 7'b0010010;
            "T", "t": ascii_to_segs = 7'b0000111;
            "U", "u": ascii_to_segs = 7'b1000001;
            "Y", "y": ascii_to_segs = 7'b0010001;
            "Z", "z": ascii_to_segs = 7'b0100100;   // rendered like "2"
            // symbols
            "-": ascii_to_segs = 7'b0111111;         // middle bar
            "_": ascii_to_segs = 7'b1110111;         // bottom bar
            // space, K/M/V/W/X, control chars, unknown → blank
            default: ascii_to_segs = 7'b1111111;
        endcase
    endfunction

    // Output multiplexer
    logic [7:0] cur_char;
    logic       cur_dp;
    logic       cur_blank;

    always_comb begin
        cur_char  = chars_i[digit_idx*8 +: 8];
        cur_dp    = dp_i[digit_idx];
        cur_blank = blank_i[digit_idx];

        if (!rst_ni || cur_blank) begin
            seg_o = 8'hFF;                                    // all off
            an_o  = 8'hFF;                                    // anode also off
        end else begin
            seg_o = {~cur_dp, ascii_to_segs(cur_char)};       // dp_i is active-high
            an_o  = ~(8'b1 << digit_idx);                     // selected digit LOW
        end
    end

endmodule
