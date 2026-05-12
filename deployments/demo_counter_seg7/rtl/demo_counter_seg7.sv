// Demo: Up/down counter on Nexys A7, value shown in hex on 8-digit 7-segment.
//   BTNC = reset (active-HIGH on board, inverted to rst_ni)
//   BTNU = count up   (debounced, +1 per press)
//   BTND = count down (debounced, -1 per press)
// 32-bit counter → full wrap across all 8 hex digits (0x00000000 ↔ 0xFFFFFFFF).
module demo_counter_seg7 (
    input  logic       clk_i,        // 100 MHz, pin E3
    input  logic       btnc_i,       // center button → reset
    input  logic       btnu_i,       // up button
    input  logic       btnd_i,       // down button

    output logic [7:0] an_o,         // 7-seg anodes,   active-LOW
    output logic [7:0] seg_o         // 7-seg segments, active-LOW: {DP,G,F,E,D,C,B,A}
);

    logic rst_ni;
    assign rst_ni = ~btnc_i;         // BTNC active-HIGH → active-LOW reset

    // Debounce both navigation buttons (default 10 ms at 100 MHz)
    logic btnu_db, btnd_db;

    debouncer u_db_up (
        .clk_i,
        .rst_ni,
        .btn_i (btnu_i),
        .btn_o (btnu_db)
    );

    debouncer u_db_dn (
        .clk_i,
        .rst_ni,
        .btn_i (btnd_i),
        .btn_o (btnd_db)
    );

    // 32-bit up/down counter (wraps across the full display range)
    logic [31:0] count;

    counter #(.AddrWidth(32)) u_counter (
        .clk_i,
        .rst_ni,
        .btn_up_i (btnu_db),
        .btn_dn_i (btnd_db),
        .addr_o   (count)
    );

    // Hex display, no DP, no blanking
    seg7 u_seg7 (
        .clk_i,
        .rst_ni,
        .value_i (count),
        .dp_i    (8'h00),
        .blank_i (8'h00),
        .an_o    (an_o),
        .seg_o   (seg_o)
    );

endmodule
