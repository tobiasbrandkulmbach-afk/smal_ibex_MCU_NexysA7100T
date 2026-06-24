`timescale 1ns/1ps
module tb_uart_tx;

    localparam int unsigned CPB = 4;   // small bit period for fast simulation

    logic       clk_i  = 0;
    logic       rst_ni = 0;
    logic       start_i = 0;
    logic [7:0] data_i  = '0;
    logic       tx_o;
    logic       busy_o;
    logic       done_o;

    always #5 clk_i = ~clk_i;

    uart_tx #(.ClksPerBit(CPB)) dut (
        .clk_i, .rst_ni, .start_i, .data_i, .tx_o, .busy_o, .done_o
    );

    int fail_count = 0;

    task automatic check(input string name, input logic [31:0] got, input logic [31:0] exp);
        if (got !== exp) begin
            $display("FAIL  [%s]  got=0x%08h  expected=0x%08h", name, got, exp);
            fail_count++;
        end else begin
            $display("ok    [%s]", name);
        end
    endtask

    // Decode one 8N1 frame off tx_o by sampling near each bit centre.
    task automatic capture_byte(output logic [7:0] b, output logic stop_ok);
        // wait for start bit (line goes low)
        @(negedge clk_i);
        while (tx_o !== 1'b0) @(negedge clk_i);
        // advance from first start-bit cycle to ~centre of data bit 0
        repeat (CPB + CPB/2) @(negedge clk_i);
        for (int i = 0; i < 8; i++) begin
            b[i] = tx_o;
            repeat (CPB) @(negedge clk_i);
        end
        stop_ok = tx_o;   // should be 1 (stop bit) at this point
    endtask

    logic [7:0] rx_byte;
    logic       stop_ok;

    initial begin
        rst_ni = 0;
        repeat (4) @(negedge clk_i);
        check("idle tx high during reset", {31'h0, tx_o}, 32'h1);
        rst_ni = 1;
        @(negedge clk_i);

        // T1: transmit 0xC3
        check("idle: not busy", {31'h0, busy_o}, 32'h0);
        data_i  = 8'hC3;
        start_i = 1;
        @(negedge clk_i);
        start_i = 0;
        check("busy asserted after start", {31'h0, busy_o}, 32'h1);

        capture_byte(rx_byte, stop_ok);
        check("T1 transmitted byte = 0xC3", {24'h0, rx_byte}, 32'hC3);
        check("T1 stop bit high", {31'h0, stop_ok}, 32'h1);

        // wait for frame to fully finish, expect done pulse + back to idle
        @(posedge done_o);
        @(negedge clk_i);
        check("idle again after frame", {31'h0, busy_o}, 32'h0);

        // T2: transmit a second, different byte (0x55) to confirm reusability
        data_i  = 8'h55;
        start_i = 1;
        @(negedge clk_i);
        start_i = 0;
        capture_byte(rx_byte, stop_ok);
        check("T2 transmitted byte = 0x55", {24'h0, rx_byte}, 32'h55);

        $display("--------------------------------------------------");
        if (fail_count == 0) $display("PASS - all tests passed.");
        else                 $display("FAIL - %0d test(s) failed.", fail_count);
        $finish;
    end

endmodule
