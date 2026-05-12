// TL-UL → simple-bus adapter ("device-side").
// Front-end speaks TL-UL (tl_h2d_t / tl_d2h_t), back-end exposes the same
// req/we/be/addr/wdata/rdata signature as lib/ram. A `bus_reg` can be inserted
// between this adapter and the peripheral without further changes.
//
// Supports Get, PutFullData, PutPartialData (single-beat). Unknown opcodes are
// completed with d_error = 1.
//
// Timing: non-pipelined. Maximum throughput is one transaction every two
// cycles (accept → response). a_ready is held LOW while a request is in
// flight; that single-slot design is sufficient for the synchronous BRAM
// behind lib/ram and keeps the FSM trivial.
//
//   Cycle 0: a_valid & a_ready → request accepted, drive req_o
//   Cycle 1: rdata_i is valid (BRAM), d_valid asserted, response returned
//   Cycle 2: req_pending cleared, ready for next request
module tl_adapter
    import tlul_pkg::*;
#(
    parameter int unsigned AddrWidth = 12   // word-address width of attached peripheral
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,

    // TL-UL (host-facing)
    input  tl_h2d_t                 tl_h2d_i,
    output tl_d2h_t                 tl_d2h_o,

    // Simple bus (peripheral-facing) — same signature as lib/ram and lib/bus_reg
    output logic                    req_o,
    output logic                    we_o,
    output logic [TL_DBW-1:0]       be_o,
    output logic [AddrWidth-1:0]    addr_o,
    output logic [TL_DW-1:0]        wdata_o,
    input  logic [TL_DW-1:0]        rdata_i
);

    // ------------------------------------------------------------------------
    // Opcode decoding (combinational, from the live a-channel)
    // ------------------------------------------------------------------------
    logic op_is_get, op_is_put_full, op_is_put_partial, op_is_write, op_is_known;
    assign op_is_get         = (tl_h2d_i.a_opcode == Get);
    assign op_is_put_full    = (tl_h2d_i.a_opcode == PutFullData);
    assign op_is_put_partial = (tl_h2d_i.a_opcode == PutPartialData);
    assign op_is_write       = op_is_put_full || op_is_put_partial;
    assign op_is_known       = op_is_get || op_is_write;

    // ------------------------------------------------------------------------
    // In-flight state (set on accept, cleared on response completion)
    // ------------------------------------------------------------------------
    logic              req_pending_q;
    tl_a_op_e          opcode_q;
    logic [TL_AIW-1:0] source_q;
    logic [TL_SZW-1:0] size_q;
    logic              err_q;

    logic accept_now;
    assign accept_now = tl_h2d_i.a_valid && tl_d2h_o.a_ready;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            req_pending_q <= 1'b0;
            opcode_q      <= Get;
            source_q      <= '0;
            size_q        <= '0;
            err_q         <= 1'b0;
        end else begin
            if (accept_now) begin
                req_pending_q <= 1'b1;
                opcode_q      <= tl_h2d_i.a_opcode;
                source_q      <= tl_h2d_i.a_source;
                size_q        <= tl_h2d_i.a_size;
                err_q         <= !op_is_known;
            end else if (tl_d2h_o.d_valid && tl_h2d_i.d_ready) begin
                req_pending_q <= 1'b0;
            end
        end
    end

    // ------------------------------------------------------------------------
    // Peripheral-side request (combinational, only during the accept cycle)
    // ------------------------------------------------------------------------
    // Strip the byte-offset LSBs from the TL-UL byte address. For TL_DBW=4
    // this drops the lowest 2 bits and uses AddrWidth bits above.
    localparam int unsigned ByteOffsetBits = $clog2(TL_DBW);

    assign req_o   = accept_now && op_is_known;
    assign we_o    = op_is_write;
    assign be_o    = op_is_get ? '0 : tl_h2d_i.a_mask;
    assign addr_o  = tl_h2d_i.a_address[ByteOffsetBits +: AddrWidth];
    assign wdata_o = tl_h2d_i.a_data;

    // ------------------------------------------------------------------------
    // TL-UL response (combinational from the latched state and rdata_i)
    // ------------------------------------------------------------------------
    assign tl_d2h_o.a_ready = !req_pending_q;

    assign tl_d2h_o.d_valid  = req_pending_q;
    assign tl_d2h_o.d_opcode = (opcode_q == Get) ? AccessAckData : AccessAck;
    assign tl_d2h_o.d_param  = 3'h0;
    assign tl_d2h_o.d_size   = size_q;
    assign tl_d2h_o.d_source = source_q;
    assign tl_d2h_o.d_data   = rdata_i;     // Only meaningful on AccessAckData
    assign tl_d2h_o.d_user   = '0;
    assign tl_d2h_o.d_error  = err_q;

endmodule
