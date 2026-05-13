// Memory-mapped peripheral register - the "Lego brick" for CSR blocks.
// Einmal bauen, überall verwenden.
//
// Bus side: same req/we/be/wdata signature family as lib/ram, but `we_i` is
// expected to be pre-filtered by the parent (req && we && address-match). The
// parent module decodes the address and muxes the registers' rdata_o back to
// the bus. There is no internal address comparator.
//
// HW side:
//   * q_o exposes the current value combinationally - peripheral logic reads
//     it with zero added latency.
//   * hw_i lets logic feed a value back into the register. In READ_ONLY mode
//     hw_i overwrites `storage` every cycle, so the bus sees a live status
//     value. In RW mode hw_i is ignored.
//
// Read timing: rdata_o is registered every cycle (1-cycle latency), matching
// the synchronous read pattern of lib/ram. No read-strobe needed - rdata_o
// always tracks `storage` one clock late.
//
//        bus side                        peripheral side
//   we/be/wdata ─►┐
//                 │  ┌───────────┐
//                 ├─►│  storage  │── q_o ────►  peripheral logic
//                 │  └─────▲─────┘
//        rdata ◄──┘        │
//                          └──── hw_i (only consumed when READ_ONLY=1)
//
// Composition pattern (e.g. inside a future uart_periph wrapper):
//
//   peri_reg #(.RESET_VAL(32'h0))                u_ctrl   (.we_i(ctrl_we),   ..., .q_o(ctrl_q));
//   peri_reg #(.RESET_VAL(32'h0))                u_data   (.we_i(data_we),   ..., .q_o(data_q));
//   peri_reg #(.RESET_VAL(32'h0), .READ_ONLY(1)) u_status (.we_i(1'b0), .hw_i(status), .q_o());
module peri_reg #(
    parameter logic [31:0] RESET_VAL = 32'h0,
    parameter bit          READ_ONLY = 1'b0
) (
    input  logic        clk_i,
    input  logic        rst_ni,   // active-low synchronous reset

    // Bus side (chip-selected by parent - no internal address decode)
    input  logic        we_i,     // pre-filtered: req && we && addr-match
    input  logic [3:0]  be_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    // HW side
    input  logic [31:0] hw_i,     // ignored when READ_ONLY=0
    output logic [31:0] q_o
);

    logic [31:0] storage;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            storage <= RESET_VAL;
        end else if (READ_ONLY) begin
            storage <= hw_i;
        end else if (we_i) begin
            if (be_i[0]) storage[7:0]   <= wdata_i[7:0];
            if (be_i[1]) storage[15:8]  <= wdata_i[15:8];
            if (be_i[2]) storage[23:16] <= wdata_i[23:16];
            if (be_i[3]) storage[31:24] <= wdata_i[31:24];
        end
    end

    // Registered read - 1-cycle latency, mirrors lib/ram timing. rdata_o
    // always tracks `storage` one clock late; no read-strobe needed.
    always_ff @(posedge clk_i) begin
        if (!rst_ni) rdata_o <= '0;
        else         rdata_o <= storage;
    end

    assign q_o = storage;

endmodule
