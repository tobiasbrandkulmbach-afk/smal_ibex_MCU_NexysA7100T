// 7-segment peripheral: two memory-mapped 32-bit registers that drive the
// 8-digit character display. Each register holds four ASCII bytes (one per
// digit); the built-in font in lib/seg7 turns them into segment patterns.
//
// Bus interface matches lib/ram/lib/uart_periph (req/we/be/addr/wdata/rdata).
// The parent decodes the peripheral base address and asserts req_i; addr_i
// selects the internal register (word offset bit).
//
//   Register map (word offset):
//     0x0  CHARS_LO  digits 0..3  -> [7:0]=digit0 (AN0, rightmost) .. [31:24]=digit3
//     0x4  CHARS_HI  digits 4..7  -> [7:0]=digit4 .. [31:24]=digit7 (AN7, leftmost)
//
//   Example: write "ABCD" to CHARS_LO (0x44434241) → four rightmost digits.
//   Read returns the last written value (1-cycle latency, like lib/ram).
//
// Decimal-point and blank control are tied off (all digits active, no dots).
// TicksPerDigit is parametrised so the testbench can run at TicksPerDigit=2.
module seg7_periph #(
    parameter int unsigned TicksPerDigit = 100_000   // 1 ms/digit at 100 MHz
) (
    input  logic        clk_i,
    input  logic        rst_ni,     // active-low synchronous reset

    // Bus interface (chip-selected by parent - single register-select bit)
    input  logic        req_i,
    input  logic        we_i,
    input  logic [3:0]  be_i,
    input  logic        addr_i,     // 0 = CHARS_LO, 1 = CHARS_HI
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    // 7-segment display outputs (Nexys A7, common-anode, active-LOW)
    output logic [7:0]  an_o,
    output logic [7:0]  seg_o
);

    logic [31:0] chars_lo;   // digits 0..3
    logic [31:0] chars_hi;   // digits 4..7

    logic lo_we, hi_we;
    assign lo_we = req_i && we_i && (addr_i == 1'b0);
    assign hi_we = req_i && we_i && (addr_i == 1'b1);

    peri_reg #(.RESET_VAL(32'h0), .READ_ONLY(1'b0)) u_lo (
        .clk_i, .rst_ni,
        .we_i   (lo_we),
        .be_i,
        .wdata_i,
        .rdata_o(),          // read handled by the mux below
        .hw_i   (32'h0),
        .q_o    (chars_lo)
    );

    peri_reg #(.RESET_VAL(32'h0), .READ_ONLY(1'b0)) u_hi (
        .clk_i, .rst_ni,
        .we_i   (hi_we),
        .be_i,
        .wdata_i,
        .rdata_o(),
        .hw_i   (32'h0),
        .q_o    (chars_hi)
    );

    // Registered read mux (1-cycle latency, captures addr_i at request time).
    always_ff @(posedge clk_i) begin
        if (!rst_ni)             rdata_o <= '0;
        else if (req_i && !we_i) rdata_o <= addr_i ? chars_hi : chars_lo;
    end

    seg7 #(
        .TicksPerDigit(TicksPerDigit)
    ) u_seg7 (
        .clk_i,
        .rst_ni,
        .chars_i({chars_hi, chars_lo}),
        .dp_i   (8'h00),
        .blank_i(8'h00),
        .an_o,
        .seg_o
    );

endmodule
