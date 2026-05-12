// Up/Down address counter with wrap-around.
// btn_up / btn_dn are expected to be already debounced level signals;
// the module detects rising edges so exactly one step fires per press.
module counter #(
    parameter int unsigned AddrWidth = 12   // 2^12 = 4096 → 16 KB word space
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,   // active-low synchronous reset

    input  logic                    btn_up_i,
    input  logic                    btn_dn_i,

    output logic [AddrWidth-1:0]    addr_o
);

    logic btn_up_prev, btn_dn_prev;
    logic up_pulse, dn_pulse;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            btn_up_prev <= 1'b0;
            btn_dn_prev <= 1'b0;
        end else begin
            btn_up_prev <= btn_up_i;
            btn_dn_prev <= btn_dn_i;
        end
    end

    assign up_pulse = btn_up_i & ~btn_up_prev;
    assign dn_pulse = btn_dn_i & ~btn_dn_prev;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            addr_o <= '0;
        end else begin
            unique case ({up_pulse, dn_pulse})
                2'b10:   addr_o <= addr_o + 1'b1;  // wraps 4095 → 0
                2'b01:   addr_o <= addr_o - 1'b1;  // wraps 0 → 4095
                default: addr_o <= addr_o;
            endcase
        end
    end

endmodule
