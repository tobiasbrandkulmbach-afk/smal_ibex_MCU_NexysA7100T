// TL-UL (TileLink Uncached Lightweight) type definitions.
// Compatible with OpenTitan TL-UL spec for single-beat single-source access.
// Reference: https://opentitan.org/book/hw/ip/tlul/
package tlul_pkg;

    // Bus widths
    parameter int unsigned TL_AW  = 32;             // address width
    parameter int unsigned TL_DW  = 32;             // data width
    parameter int unsigned TL_DBW = TL_DW / 8;      // data byte width (4)
    parameter int unsigned TL_SZW = 2;              // size width (encodes 2^size bytes)
    parameter int unsigned TL_AIW = 8;              // source-id width
    parameter int unsigned TL_DUW = 4;              // user bits (OT-spezifisch, hier unused)

    // A-channel opcodes
    typedef enum logic [2:0] {
        PutFullData    = 3'h0,
        PutPartialData = 3'h1,
        Get            = 3'h4
    } tl_a_op_e;

    // D-channel opcodes
    typedef enum logic [2:0] {
        AccessAck     = 3'h0,
        AccessAckData = 3'h1
    } tl_d_op_e;

    // Host → Device: A-channel payload + D-channel ready
    typedef struct packed {
        logic                  a_valid;
        tl_a_op_e              a_opcode;
        logic [2:0]            a_param;
        logic [TL_SZW-1:0]     a_size;
        logic [TL_AIW-1:0]     a_source;
        logic [TL_AW-1:0]      a_address;
        logic [TL_DBW-1:0]     a_mask;
        logic [TL_DW-1:0]      a_data;
        logic [TL_DUW-1:0]     a_user;
        logic                  d_ready;
    } tl_h2d_t;

    // Device → Host: D-channel payload + A-channel ready
    typedef struct packed {
        logic                  d_valid;
        tl_d_op_e              d_opcode;
        logic [2:0]            d_param;
        logic [TL_SZW-1:0]     d_size;
        logic [TL_AIW-1:0]     d_source;
        logic [TL_DW-1:0]      d_data;
        logic [TL_DUW-1:0]     d_user;
        logic                  d_error;
        logic                  a_ready;
    } tl_d2h_t;

endpackage
