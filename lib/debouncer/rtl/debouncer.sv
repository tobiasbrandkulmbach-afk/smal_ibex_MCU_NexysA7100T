// Synchronous button debouncer.
// Output changes only after the input has been stable for CntMax clock cycles.
// Default: CntMax = 1_000_000 → 10 ms at 100 MHz.
module debouncer #(
    parameter int unsigned CntMax = 1_000_000
) (
    input  logic clk_i,
    input  logic rst_ni,   // active-low synchronous reset

    input  logic btn_i,    // raw button input (active-high)
    output logic btn_o     // debounced output
);

    localparam int unsigned CntW = $clog2(CntMax + 1);

    logic [CntW-1:0] cnt;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            cnt   <= '0;
            btn_o <= 1'b0;
        end else begin
            if (btn_i == btn_o) begin
                // Input matches output – no pending change, reset counter.
                cnt <= '0;
            end else begin
                if (cnt == CntMax[CntW-1:0] - 1) begin
                    // Input has been stable long enough – commit the change.
                    btn_o <= btn_i;
                    cnt   <= '0;
                end else begin
                    cnt <= cnt + 1'b1;
                end
            end
        end
    end

endmodule
