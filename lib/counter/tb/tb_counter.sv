`timescale 1ns/1ps
module tb_counter;

    localparam int unsigned AW = 12;
    localparam int unsigned MAX = (1 << AW) - 1;   // 4095

    logic             clk_i   = 0;
    logic             rst_ni  = 0;
    logic             btn_up_i = 0;
    logic             btn_dn_i = 0;
    logic [AW-1:0]    addr_o;

    always #5 clk_i = ~clk_i;

    counter #(.AddrWidth(AW)) dut (.*);

    int fail_count = 0;

    task automatic tick(input int n = 1);
        repeat(n) @(posedge clk_i); #1;
    endtask

    // Simulate one button press: assert for 2 cycles, then release.
    task automatic press_up();
        btn_up_i = 1; tick(2); btn_up_i = 0; tick(1);
    endtask

    task automatic press_dn();
        btn_dn_i = 1; tick(2); btn_dn_i = 0; tick(1);
    endtask

    task automatic check(input string name, input logic [AW-1:0] got, input logic [AW-1:0] exp);
        if (got !== exp) begin
            $display("FAIL  [%s]  got=%0d  expected=%0d", name, got, exp);
            fail_count++;
        end else begin
            $display("ok    [%s]  addr=%0d", name, got);
        end
    endtask

    initial begin
        tick(2);
        rst_ni = 1;
        tick(1);

        // T1: Reset leaves counter at 0
        check("T1 reset", addr_o, 0);

        // T2: Single up press → 1
        press_up();
        check("T2 up x1", addr_o, 1);

        // T3: Three more up presses → 4
        press_up(); press_up(); press_up();
        check("T3 up x3", addr_o, 4);

        // T4: Single down press → 3
        press_dn();
        check("T4 dn x1", addr_o, 3);

        // T5: Simultaneous up+dn → no change
        btn_up_i = 1; btn_dn_i = 1; tick(2);
        btn_up_i = 0; btn_dn_i = 0; tick(1);
        check("T5 simultaneous", addr_o, 3);

        // T6: Wrap-around upward (0 → MAX → 0)
        rst_ni = 0; tick(1); rst_ni = 1; tick(1);
        // Set to MAX by counting down once from 0 (wrap)
        press_dn();
        check("T6a wrap dn 0→MAX", addr_o, MAX);
        // Now one more up wraps back to 0
        press_up();
        check("T6b wrap up MAX→0", addr_o, 0);

        // T7: Reset mid-count returns to 0
        press_up(); press_up(); press_up();
        rst_ni = 0; tick(1); rst_ni = 1; tick(1);
        check("T7 mid-count reset", addr_o, 0);

        // T8: Button held for multiple cycles fires only once
        btn_up_i = 1; tick(5); btn_up_i = 0; tick(1);
        check("T8 held btn fires once", addr_o, 1);

        $display("--------------------------------------------------");
        if (fail_count == 0)
            $display("PASS – all tests passed.");
        else
            $display("FAIL – %0d test(s) failed.", fail_count);

        $finish;
    end

endmodule
