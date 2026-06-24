`timescale 1ns/1ps
module tb_uart_rx;

    localparam int unsigned CPB = 4;   // small bit period for fast simulation

    logic       clk_i  = 0;
    logic       rst_ni = 0;
    logic       rx_i   = 1;   // idle high
    logic [7:0] data_o;
    logic       valid_o;

    always #5 clk_i = ~clk_i;

    uart_rx #(.ClksPerBit(CPB)) dut (
        .clk_i, .rst_ni, .rx_i, .data_o, .valid_o
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

    // Drive one 8N1 frame onto rx_i, LSB first.
    task automatic send_byte(input logic [7:0] b);
        // start bit
        rx_i = 1'b0;
        repeat (CPB) @(negedge clk_i);
        // data bits
        for (int i = 0; i < 8; i++) begin
            rx_i = b[i];
            repeat (CPB) @(negedge clk_i);
        end
        // stop bit
        rx_i = 1'b1;
        repeat (CPB) @(negedge clk_i);
    endtask

    initial begin
        rst_ni = 0;
        repeat (4) @(negedge clk_i);
        rst_ni = 1;
        repeat (2) @(negedge clk_i);

        // T1: receive 0x96
        send_byte(8'h96);
        @(posedge valid_o);
        check("T1 received byte = 0x96", {24'h0, data_o}, 32'h96);

        // a few idle cycles
        repeat (4) @(negedge clk_i);

        // T2: receive 0x3A
        send_byte(8'h3A);
        @(posedge valid_o);
        check("T2 received byte = 0x3A", {24'h0, data_o}, 32'h3A);

        // T3: receive 0xFF then 0x00 (all-ones / all-zeros edge cases)
        send_byte(8'hFF);
        @(posedge valid_o);
        check("T3a received byte = 0xFF", {24'h0, data_o}, 32'hFF);
        repeat (4) @(negedge clk_i);
        send_byte(8'h00);
        @(posedge valid_o);
        check("T3b received byte = 0x00", {24'h0, data_o}, 32'h00);

        $display("--------------------------------------------------");
        if (fail_count == 0) $display("PASS - all tests passed.");
        else                 $display("FAIL - %0d test(s) failed.", fail_count);
        $finish;
    end

endmodule
