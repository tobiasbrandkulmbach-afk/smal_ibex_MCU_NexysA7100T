// Single memory-mapped configuration register - the "Lego brick" out of which
// peripheral CSR blocks are built. One instance = one bus address.
//
// Bus side mirrors lib/ram's signature so a tl_adapter (or a bus_reg array
// behind a small address decoder) can drive it without translation. There is
// no internal address comparator: the parent module decodes addr → req_i for
// each register, and muxes the registers' rdata_o back to the bus.
//
// Peripheral side exposes value_o, the live contents of the register, as
// parallel wires. The peripheral logic reads value_o combinationally - no
// extra latency.
//
//        bus side                       peripheral side
//   req/we/be/wdata ──►┐
//                      │ ┌───────────┐
//                      ├►│  value_q  │── value_o ─►  peripheral logic
//                      │ └───────────┘
//        rdata ◄───────┘     (registered read,
//                             1-cycle latency,
//                             matches lib/ram)
//
// Composition pattern (e.g. inside a future uart_periph wrapper):
//
//   bus_reg u_ctrl   (.req_i(ctrl_sel),   ..., .value_o(ctrl_value));
//   bus_reg u_data   (.req_i(data_sel),   ..., .value_o(data_value));
//   bus_reg u_status (.req_i(status_sel), ..., .value_o(status_value));
module bus_reg #(
    parameter int unsigned         DataWidth  = 32,
    parameter logic [31:0]         ResetValue = 32'h0
) (
    input  logic                        clk_i,
    input  logic                        rst_ni,   // active-low synchronous reset

    // Bus side (chip-selected by parent - no internal address decode)
    input  logic                        req_i,
    input  logic                        we_i,
    input  logic [DataWidth/8-1:0]      be_i,
    input  logic [DataWidth-1:0]        wdata_i,
    output logic [DataWidth-1:0]        rdata_o,

    // Peripheral side (always reflects the stored value)
    output logic [DataWidth-1:0]        value_o
);

    localparam int unsigned ByteWidth = DataWidth / 8;

    logic [DataWidth-1:0] value_q;

    // Byte-granular synchronous write
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            value_q <= ResetValue[DataWidth-1:0];
        end else if (req_i && we_i) begin
            for (int unsigned i = 0; i < ByteWidth; i++) begin
                if (be_i[i]) value_q[i*8 +: 8] <= wdata_i[i*8 +: 8];
            end
        end
    end

    // Registered read - 1-cycle latency to match lib/ram (and the tl_adapter's
    // assumed timing). Only updates on an actual read request, so rdata_o
    // holds its previous value when idle.
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            rdata_o <= '0;
        end else if (req_i && !we_i) begin
            rdata_o <= value_q;
        end
    end

    assign value_o = value_q;

endmodule
