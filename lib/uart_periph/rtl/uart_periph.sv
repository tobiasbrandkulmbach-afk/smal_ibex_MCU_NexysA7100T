// UART peripheral: memory-mapped wrapper around uart_tx + uart_rx.
//
// Bus interface follows the project convention (req/we/be/wdata/rdata, 1-cycle
// registered read latency like lib/ram and lib/peri_reg). The parent decodes
// the peripheral base address and asserts req_i; addr_i selects the internal
// register (word offset = byte address bits [3:2]).
//
// Register map (word offset):
//   0x0  DATA    W: low byte → transmit (only when tx_ready)
//                R: last received byte; reading clears rx_valid/overrun
//   0x4  STATUS  R: bit0 tx_ready (1 = TX idle, ready for new byte)
//                   bit1 rx_valid (1 = a received byte is waiting)
//                   bit2 rx_overrun (1 = a byte was lost before being read)
//
// Baud rate is derived from ClkFreq/BaudRate at elaboration. be_i is accepted
// for signature compatibility but ignored (this is a byte-wide device).
module uart_periph #(
    parameter int unsigned ClkFreq  = 100_000_000,   // system clock in Hz
    parameter int unsigned BaudRate = 115_200
) (
    input  logic        clk_i,
    input  logic        rst_ni,      // active-low synchronous reset

    // Bus interface (chip-selected by parent)
    input  logic        req_i,
    input  logic        we_i,
    input  logic [3:0]  be_i,        // ignored (byte device)
    input  logic [1:0]  addr_i,      // register select (word offset)
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    // Serial pins
    output logic        tx_o,        // to RS-232 / USB-UART TX
    input  logic        rx_i         // from RS-232 / USB-UART RX
);

    localparam int unsigned ClksPerBit = ClkFreq / BaudRate;

    localparam logic [1:0] REG_DATA   = 2'd0;
    localparam logic [1:0] REG_STATUS = 2'd1;

    // --- Access strobes ----------------------------------------------------
    logic wr_data, rd_data;
    assign wr_data = req_i &&  we_i && (addr_i == REG_DATA);
    assign rd_data = req_i && !we_i && (addr_i == REG_DATA);

    // --- Transmitter -------------------------------------------------------
    logic tx_busy;
    logic tx_start;
    assign tx_start = wr_data && !tx_busy;   // drop write if busy (SW polls tx_ready)

    uart_tx #(.ClksPerBit(ClksPerBit)) u_tx (
        .clk_i,
        .rst_ni,
        .start_i (tx_start),
        .data_i  (wdata_i[7:0]),
        .tx_o    (tx_o),
        .busy_o  (tx_busy),
        .done_o  ()
    );

    // --- Receiver ----------------------------------------------------------
    logic [7:0] rx_data;
    logic       rx_strobe;

    uart_rx #(.ClksPerBit(ClksPerBit)) u_rx (
        .clk_i,
        .rst_ni,
        .rx_i    (rx_i),
        .data_o  (rx_data),
        .valid_o (rx_strobe)
    );

    // --- RX holding register + status flags --------------------------------
    logic [7:0] rx_buf;
    logic       rx_valid;
    logic       rx_overrun;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            rx_buf     <= '0;
            rx_valid   <= 1'b0;
            rx_overrun <= 1'b0;
        end else begin
            // Read of DATA consumes the byte (clears flags). Listed first so a
            // simultaneously arriving byte (below) still wins and stays valid.
            if (rd_data) begin
                rx_valid   <= 1'b0;
                rx_overrun <= 1'b0;
            end
            if (rx_strobe) begin
                rx_buf   <= rx_data;
                rx_valid <= 1'b1;
                if (rx_valid) rx_overrun <= 1'b1;   // previous byte never read
            end
        end
    end

    // --- Registered read mux (1-cycle latency, matches lib/ram) ------------
    logic [31:0] status_word;
    assign status_word = {29'h0, rx_overrun, rx_valid, ~tx_busy};

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            rdata_o <= '0;
        end else if (req_i && !we_i) begin
            unique case (addr_i)
                REG_DATA:   rdata_o <= {24'h0, rx_buf};
                REG_STATUS: rdata_o <= status_word;
                default:    rdata_o <= '0;
            endcase
        end
    end

endmodule
