// UART receiver, 8N1 (8 data bits, no parity, 1 stop bit), LSB first.
// Idle line = HIGH. One bit lasts ClksPerBit clock cycles.
//
// The asynchronous rx_i is passed through a 2-FF synchronizer. A start bit is
// detected as a HIGH→LOW transition; it is re-checked at the middle of the
// start bit to reject glitches. Data bits are sampled at their centre.
//
//   data_o  holds the received byte.
//   valid_o pulses for 1 cycle when data_o is valid (end of stop bit).
module uart_rx #(
    parameter int unsigned ClksPerBit = 868   // 100 MHz / 115200 ≈ 868
) (
    input  logic       clk_i,
    input  logic       rst_ni,      // active-low synchronous reset

    input  logic       rx_i,        // asynchronous serial input

    output logic [7:0] data_o,      // received byte
    output logic       valid_o      // 1-cycle pulse when data_o is valid
);

    // --- 2-FF synchronizer (idle = HIGH, so reset to 1) -------------------
    logic rx_meta, rx_sync;
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx_i;
            rx_sync <= rx_meta;
        end
    end

    typedef enum logic [1:0] { IDLE, START, DATA, STOP } state_e;
    state_e state;

    logic [$clog2(ClksPerBit):0] clk_cnt;
    logic [2:0]                  bit_idx;
    logic [7:0]                  shreg;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            state   <= IDLE;
            clk_cnt <= '0;
            bit_idx <= '0;
            shreg   <= '0;
            data_o  <= '0;
            valid_o <= 1'b0;
        end else begin
            valid_o <= 1'b0;   // default: only pulses for one cycle

            unique case (state)
                IDLE: begin
                    clk_cnt <= '0;
                    bit_idx <= '0;
                    if (!rx_sync) begin       // falling edge → possible start bit
                        state <= START;
                    end
                end

                START: begin
                    // sample at the middle of the start bit to confirm
                    if (clk_cnt == (ClksPerBit-1)/2) begin
                        if (!rx_sync) begin
                            clk_cnt <= '0;
                            state   <= DATA;  // confirmed
                        end else begin
                            state   <= IDLE;  // false start (glitch)
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                DATA: begin
                    // one full bit period after the start-bit centre lands on
                    // the centre of each data bit
                    if (clk_cnt == ClksPerBit-1) begin
                        clk_cnt        <= '0;
                        shreg[bit_idx] <= rx_sync;
                        if (bit_idx == 3'd7) begin
                            bit_idx <= '0;
                            state   <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                STOP: begin
                    if (clk_cnt == ClksPerBit-1) begin
                        clk_cnt <= '0;
                        data_o  <= shreg;
                        valid_o <= 1'b1;
                        state   <= IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
