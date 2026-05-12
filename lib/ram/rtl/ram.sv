// Single-port RAM with byte enables.
// Synchronous read → Vivado infers Block RAM (not distributed RAM).
// Use as program memory: tie we_i=0, be_i=0, set MemFile parameter.
// Use as data memory:    drive we_i/be_i from bus adapter.
module ram #(
    parameter int unsigned DataWidth = 32,
    parameter int unsigned AddrWidth = 12,    // depth = 2^AddrWidth words (default: 4096 × 32 bit = 16 KB)
    parameter string       MemFile   = ""     // optional hex init file ($readmemh format)
) (
    input  logic                        clk_i,

    // Request channel
    input  logic                        req_i,   // access enable (gates read and write)
    input  logic                        we_i,    // 1 = write, 0 = read
    input  logic [DataWidth/8-1:0]      be_i,    // byte enables (only evaluated on write)
    input  logic [AddrWidth-1:0]        addr_i,
    input  logic [DataWidth-1:0]        wdata_i,

    // Response (one cycle latency – matches synchronous BRAM read)
    output logic [DataWidth-1:0]        rdata_o
);

    localparam int unsigned Depth     = 2 ** AddrWidth;
    localparam int unsigned ByteWidth = DataWidth / 8;

    // Explicit BRAM attribute – prevents Vivado from choosing distributed RAM
    (* ram_style = "block" *)
    logic [DataWidth-1:0] mem [0:Depth-1];

    initial begin
        if (MemFile != "") $readmemh(MemFile, mem);
    end

    // Byte-granular synchronous write
    always_ff @(posedge clk_i) begin
        if (req_i && we_i) begin
            for (int unsigned i = 0; i < ByteWidth; i++) begin
                if (be_i[i]) mem[addr_i][i*8 +: 8] <= wdata_i[i*8 +: 8];
            end
        end
    end

    // Synchronous read – required for BRAM inference
    always_ff @(posedge clk_i) begin
        if (req_i) rdata_o <= mem[addr_i];
    end

endmodule
