// Demo: Counter → RAM → 7-segment.
//   BTNC = reset (active-HIGH on board)
//   BTNU = address +1 (debounced)
//   BTND = address -1 (debounced)
//   SW[0] selects RAM bank:
//     0 → addresses 0..15  (hex constants)
//     1 → addresses 16..31 (animation frames – moving dot)
// RAM is preloaded from anim.mem; the word at the current address is shown
// on the 8-digit hex display.
module demo_counter_ram_seg7 (
    input  logic       clk_i,        // 100 MHz, pin E3
    input  logic       btnc_i,       // center button → reset
    input  logic       btnu_i,
    input  logic       btnd_i,
    input  logic       sw0_i,        // bank select

    output logic [7:0] an_o,
    output logic [7:0] seg_o
);

    logic rst_ni;
    assign rst_ni = ~btnc_i;

    // Debounce navigation buttons
    logic btnu_db, btnd_db;
    debouncer u_db_up (.clk_i, .rst_ni, .btn_i(btnu_i), .btn_o(btnu_db));
    debouncer u_db_dn (.clk_i, .rst_ni, .btn_i(btnd_i), .btn_o(btnd_db));

    // 4-bit address counter (16 frames per bank, wraps)
    logic [3:0] count;
    counter #(.AddrWidth(4)) u_counter (
        .clk_i,
        .rst_ni,
        .btn_up_i (btnu_db),
        .btn_dn_i (btnd_db),
        .addr_o   (count)
    );

    // Synchronize SW[0] into clock domain (2-FF synchronizer)
    logic sw0_sync_q1, sw0_sync_q2;
    always_ff @(posedge clk_i) begin
        sw0_sync_q1 <= sw0_i;
        sw0_sync_q2 <= sw0_sync_q1;
    end

    // 32-word RAM (5-bit address), preloaded with anim.mem
    logic [4:0]  ram_addr;
    logic [31:0] ram_data;
    assign ram_addr = {sw0_sync_q2, count};

    ram #(
        .DataWidth (32),
        .AddrWidth (5),
        .MemFile   ("anim.mem")
    ) u_ram (
        .clk_i,
        .req_i   (1'b1),
        .we_i    (1'b0),
        .be_i    (4'h0),
        .addr_i  (ram_addr),
        .wdata_i (32'h0),
        .rdata_o (ram_data)
    );

    // Hex display
    seg7_hex u_seg7 (
        .clk_i,
        .rst_ni,
        .value_i (ram_data),
        .dp_i    (8'h00),
        .blank_i (8'h00),
        .an_o    (an_o),
        .seg_o   (seg_o)
    );

endmodule
