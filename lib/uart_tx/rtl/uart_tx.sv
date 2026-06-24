// UART transmitter, 8N1 (8 data bits, no parity, 1 stop bit), LSB first.
// Idle line = HIGH. One bit lasts ClksPerBit clock cycles.
//
//   start_i (1-cycle pulse) latches data_i and begins a frame.
//   busy_o  is HIGH from start until the stop bit is finished.
//   done_o  pulses for 1 cycle when the frame is fully transmitted.
//
// Frame on tx_o:  start(0) | d0 d1 .. d7 | stop(1)
module uart_tx #(
    parameter int unsigned ClksPerBit = 868   // 100 MHz / 115200 ≈ 868
) (
    input  logic       clk_i,
    input  logic       rst_ni,      // active-low synchronous reset

    input  logic       start_i,     // 1-cycle pulse: begin transmission
    input  logic [7:0] data_i,      // byte to send (sampled on start_i)

    output logic       tx_o,        // serial output, idle HIGH
    output logic       busy_o,      // HIGH while a frame is in flight
    output logic       done_o       // 1-cycle pulse at end of frame
);

    typedef enum logic [1:0] { IDLE, START, DATA, STOP } state_e;
    state_e state;

    // Counter wide enough to hold ClksPerBit-1.
    logic [$clog2(ClksPerBit):0] clk_cnt;
    logic [2:0]                  bit_idx;
    logic [7:0]                  shreg;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            state   <= IDLE;
            tx_o    <= 1'b1;
            busy_o  <= 1'b0;
            done_o  <= 1'b0;
            clk_cnt <= '0;
            bit_idx <= '0;
            shreg   <= '0;
        end else begin
            done_o <= 1'b0;   // default: only pulses for one cycle in STOP

            unique case (state)
                IDLE: begin
                    tx_o    <= 1'b1;     // idle high
                    busy_o  <= 1'b0;
                    clk_cnt <= '0;
                    bit_idx <= '0;
                    if (start_i) begin
                        shreg  <= data_i;
                        busy_o <= 1'b1;
                        state  <= START;
                    end
                end

                START: begin
                    tx_o <= 1'b0;        // start bit
                    if (clk_cnt == ClksPerBit-1) begin
                        clk_cnt <= '0;
                        state   <= DATA;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                DATA: begin
                    tx_o <= shreg[bit_idx];
                    if (clk_cnt == ClksPerBit-1) begin
                        clk_cnt <= '0;
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
                    tx_o <= 1'b1;        // stop bit
                    if (clk_cnt == ClksPerBit-1) begin
                        clk_cnt <= '0;
                        busy_o  <= 1'b0;
                        done_o  <= 1'b1;
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
