// Hex-Adapter fuer die Zeichen-7-Segment-Anzeige (lib/seg7).
//
// Nimmt einen 32-Bit-Wert und zeigt ihn als 8 Hex-Ziffern an - genau das
// Verhalten des frueheren hex-basierten seg7. Intern werden die 8 Nibbles in
// ASCII-Zeichen ('0'-'9','A'-'F') gewandelt und an das zeichenbasierte seg7
// weitergereicht. Port-kompatibel zum alten seg7 (value_i/dp_i/blank_i),
// damit bestehende Deployments als Drop-in umstellbar sind.
//
//   value_i[3:0]   -> Stelle 0 (rechts, AN[0])
//   value_i[31:28] -> Stelle 7 (links,  AN[7])
module seg7_hex #(
    parameter int unsigned TicksPerDigit = 100_000
) (
    input  logic        clk_i,
    input  logic        rst_ni,

    input  logic [31:0] value_i,        // 32-Bit-Wert -> 8 Hex-Ziffern
    input  logic [7:0]  dp_i,           // Dezimalpunkte, 1 = an, je Stelle
    input  logic [7:0]  blank_i,        // Austasten, 1 = aus, je Stelle

    output logic [7:0]  an_o,
    output logic [7:0]  seg_o
);

    // Nibble (0..15) -> ASCII-Hex-Zeichen.
    function automatic logic [7:0] nib2asc(input logic [3:0] n);
        nib2asc = (n < 4'd10) ? (8'h30 + {4'h0, n})            // '0'..'9'
                              : (8'h41 + {4'h0, (n - 4'd10)}); // 'A'..'F'
    endfunction

    logic [63:0] chars;
    always_comb begin
        for (int i = 0; i < 8; i++) begin
            chars[i*8 +: 8] = nib2asc(value_i[i*4 +: 4]);
        end
    end

    seg7 #(
        .TicksPerDigit(TicksPerDigit)
    ) u_seg7 (
        .clk_i,
        .rst_ni,
        .chars_i(chars),
        .dp_i,
        .blank_i,
        .an_o,
        .seg_o
    );

endmodule
