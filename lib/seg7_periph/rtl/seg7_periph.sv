// 7-segment peripheral: one memory-mapped 32-bit register that drives the
// 8-digit hex display.
//
// Bus interface matches lib/ram (req/we/be/wdata/rdata). The parent decodes
// the address and asserts req_i only when this peripheral is selected; there
// is no internal address comparator.
//
//   Write 0xDEAD_BEEF → display shows "DEADBEEF"
//   Read  always returns the last written value (1-cycle latency, via peri_reg)
//
// Decimal-point and blank control are tied off (all digits active, no dots).
// TicksPerDigit is parametrised so the testbench can run at TicksPerDigit=2.
module seg7_periph #(
    parameter int unsigned TicksPerDigit = 100_000   // 1 ms/digit at 100 MHz
) (
    input  logic        clk_i,
    input  logic        rst_ni,     // active-low synchronous reset

    // Bus interface (same signature as lib/ram - single address, no decoder)
    input  logic        req_i,
    input  logic        we_i,
    input  logic [3:0]  be_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    // 7-segment display outputs (Nexys A7, common-anode, active-LOW)
    output logic [7:0]  an_o,
    output logic [7:0]  seg_o
);

    logic [31:0] display_val;

    peri_reg #(
        .RESET_VAL(32'h0),
        .READ_ONLY(1'b0)
    ) u_val (
        .clk_i,
        .rst_ni,
        .we_i   (req_i && we_i),
        .be_i,
        .wdata_i,
        .rdata_o,
        .hw_i   (32'h0),
        .q_o    (display_val)
    );

    seg7 #(
        .TicksPerDigit(TicksPerDigit)
    ) u_seg7 (
        .clk_i,
        .rst_ni,
        .value_i(display_val),
        .dp_i   (8'h00),
        .blank_i(8'h00),
        .an_o,
        .seg_o
    );

endmodule
