`timescale 1ns/1ps
module tb_debouncer;

    // Small CntMax so simulation stays fast; logic is identical to real value.
    localparam int unsigned CNT = 8;

    logic clk_i  = 0;
    logic rst_ni = 0;
    logic btn_i  = 0;
    logic btn_o;

    always #5 clk_i = ~clk_i;

    debouncer #(.CntMax(CNT)) dut (.*);

    int fail_count = 0;

    task automatic tick(input int n = 1);
        repeat(n) @(posedge clk_i); #1;
    endtask

    task automatic check(input string name, input logic got, input logic exp);
        if (got !== exp) begin
            $display("FAIL  [%s]  got=%0b  expected=%0b", name, got, exp);
            fail_count++;
        end else begin
            $display("ok    [%s]  btn_o=%0b", name, got);
        end
    endtask

    initial begin
        tick(2);
        rst_ni = 1;
        tick(1);

        // T1: Output starts at 0 after reset.
        check("T1 reset", btn_o, 0);

        // T2: Clean press – hold for exactly CntMax cycles → output goes high.
        btn_i = 1;
        tick(CNT - 1);
        check("T2a not yet stable", btn_o, 0);
        tick(1);
        check("T2b stable → high", btn_o, 1);

        // T3: Clean release – hold low for CntMax cycles → output goes low.
        btn_i = 0;
        tick(CNT - 1);
        check("T3a not yet stable", btn_o, 1);
        tick(1);
        check("T3b stable → low", btn_o, 0);

        // T4: Glitch shorter than CntMax – output must NOT change.
        btn_i = 1; tick(CNT - 2); btn_i = 0; tick(2);
        check("T4 glitch rejected", btn_o, 0);

        // T5: Glitch resets counter – full CntMax needed after noise settles.
        //     Toggle several times then hold steady.
        btn_i = 1; tick(3);
        btn_i = 0; tick(2);   // counter reset by falling edge
        btn_i = 1; tick(3);
        btn_i = 0; tick(2);   // counter reset again
        check("T5a still low after noise", btn_o, 0);
        // Now hold steadily high for full CntMax → should commit.
        btn_i = 1; tick(CNT);
        check("T5b committed after steady", btn_o, 1);

        // T6: Synchronous reset clears output immediately.
        rst_ni = 0; tick(1);
        check("T6 reset clears output", btn_o, 0);
        rst_ni = 1;

        // T7: Button already high when reset released – must wait CntMax.
        // (btn_i is still 1 from T5)
        tick(CNT - 1);
        check("T7a not yet (post-reset)", btn_o, 0);
        tick(1);
        check("T7b high after CntMax", btn_o, 1);

        $display("--------------------------------------------------");
        if (fail_count == 0)
            $display("PASS – all tests passed.");
        else
            $display("FAIL – %0d test(s) failed.", fail_count);

        $finish;
    end

endmodule
