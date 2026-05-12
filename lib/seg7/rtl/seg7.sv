// 8-digit hex 7-segment controller for Nexys A7 (common-anode, active-LOW).
// Displays a 32-bit value as 8 hex digits.
//   value_i[3:0]   → digit 0 (rightmost, AN[0])
//   value_i[31:28] → digit 7 (leftmost,  AN[7])
// Time-multiplexes through all 8 digits: each digit is lit for TicksPerDigit
// clock cycles. Default 100_000 → 1 ms per digit at 100 MHz (125 Hz full
// refresh, ~1 kHz per digit slot per CLAUDE.md).
// Segment mapping seg_o[7:0] = {DP, G, F, E, D, C, B, A}, active-LOW.
module seg7 #(
    parameter int unsigned TicksPerDigit = 100_000
) (
    input  logic        clk_i,
    input  logic        rst_ni,         // active-low synchronous reset

    input  logic [31:0] value_i,        // 32-bit hex value to display
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

    // Hex nibble → 7 segments (g,f,e,d,c,b,a), active-LOW
    function automatic logic [6:0] hex_to_segs(input logic [3:0] h);
        case (h)
            4'h0: hex_to_segs = 7'b1000000;
            4'h1: hex_to_segs = 7'b1111001;
            4'h2: hex_to_segs = 7'b0100100;
            4'h3: hex_to_segs = 7'b0110000;
            4'h4: hex_to_segs = 7'b0011001;
            4'h5: hex_to_segs = 7'b0010010;
            4'h6: hex_to_segs = 7'b0000010;
            4'h7: hex_to_segs = 7'b1111000;
            4'h8: hex_to_segs = 7'b0000000;
            4'h9: hex_to_segs = 7'b0010000;
            4'hA: hex_to_segs = 7'b0001000;
            4'hB: hex_to_segs = 7'b0000011;
            4'hC: hex_to_segs = 7'b1000110;
            4'hD: hex_to_segs = 7'b0100001;
            4'hE: hex_to_segs = 7'b0000110;
            4'hF: hex_to_segs = 7'b0001110;
            default: hex_to_segs = 7'b1111111;     // safe-blank on X/Z
        endcase
    endfunction

    // Output multiplexer
    logic [3:0] cur_nibble;
    logic       cur_dp;
    logic       cur_blank;

    always_comb begin
        cur_nibble = value_i[digit_idx*4 +: 4];
        cur_dp     = dp_i[digit_idx];
        cur_blank  = blank_i[digit_idx];

        if (!rst_ni || cur_blank) begin
            seg_o = 8'hFF;                                    // all off
            an_o  = 8'hFF;                                    // anode also off
        end else begin
            seg_o = {~cur_dp, hex_to_segs(cur_nibble)};       // dp_i is active-high
            an_o  = ~(8'b1 << digit_idx);                     // selected digit LOW
        end
    end

endmodule
