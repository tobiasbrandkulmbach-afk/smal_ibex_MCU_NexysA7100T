`timescale 1ns/1ps
module tb_uart_periph;

    // ClkFreq/BaudRate = 40/10 → ClksPerBit = 4 (fast simulation).
    localparam int unsigned CLK_FREQ = 40;
    localparam int unsigned BAUD     = 10;

    localparam logic [1:0] REG_DATA   = 2'd0;
    localparam logic [1:0] REG_STATUS = 2'd1;

    logic        clk_i  = 0;
    logic        rst_ni = 0;
    logic        req_i  = 0;
    logic        we_i   = 0;
    logic [3:0]  be_i   = '0;
    logic [1:0]  addr_i = '0;
    logic [31:0] wdata_i = '0;
    logic [31:0] rdata_o;
    logic        tx_o;
    logic        rx_i;

    // Loopback: TX feeds RX.
    assign rx_i = tx_o;

    always #5 clk_i = ~clk_i;

    uart_periph #(
        .ClkFreq (CLK_FREQ),
        .BaudRate(BAUD)
    ) dut (
        .clk_i, .rst_ni,
        .req_i, .we_i, .be_i, .addr_i, .wdata_i, .rdata_o,
        .tx_o, .rx_i
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

    task automatic bus_write(input logic [1:0] a, input logic [31:0] d);
        @(negedge clk_i);
        req_i = 1; we_i = 1; be_i = 4'b1111; addr_i = a; wdata_i = d;
        @(negedge clk_i);
        req_i = 0; we_i = 0;
    endtask

    // Registered read: assert req for one cycle, value appears next cycle.
    task automatic bus_read(input logic [1:0] a, output logic [31:0] d);
        @(negedge clk_i);
        req_i = 1; we_i = 0; be_i = '0; addr_i = a;
        @(negedge clk_i);
        req_i = 0;
        d = rdata_o;
    endtask

    // Poll STATUS until rx_valid (bit1) is set, with a timeout.
    task automatic wait_rx_valid;
        logic [31:0] st;
        int timeout = 2000;
        do begin
            bus_read(REG_STATUS, st);
            timeout--;
        end while (st[1] !== 1'b1 && timeout > 0);
        if (timeout == 0) begin
            $display("FAIL  [wait_rx_valid] timed out");
            fail_count++;
        end
    endtask

    logic [31:0] rd;

    initial begin
        rst_ni = 0;
        repeat (4) @(negedge clk_i);
        rst_ni = 1;
        repeat (2) @(negedge clk_i);

        // T0: after reset TX ready, nothing received
        bus_read(REG_STATUS, rd);
        check("T0 tx_ready set",  {31'h0, rd[0]}, 32'h1);
        check("T0 rx_valid clear",{31'h0, rd[1]}, 32'h0);

        // T1: send 0x5A via DATA write; loopback returns it to RX
        bus_write(REG_DATA, 32'h0000_005A);
        wait_rx_valid();
        bus_read(REG_DATA, rd);
        check("T1 received 0x5A", rd, 32'h0000_005A);

        // after consuming, rx_valid must clear
        bus_read(REG_STATUS, rd);
        check("T1 rx_valid cleared after read", {31'h0, rd[1]}, 32'h0);

        // T2: send a second byte 0xA5
        bus_write(REG_DATA, 32'h0000_00A5);
        wait_rx_valid();
        bus_read(REG_DATA, rd);
        check("T2 received 0xA5", rd, 32'h0000_00A5);

        // T3: overrun — send two bytes without reading the first
        bus_write(REG_DATA, 32'h0000_0011);
        wait_rx_valid();                 // first byte arrives, left unread
        // do NOT read; wait for TX ready, then send the next byte
        do bus_read(REG_STATUS, rd); while (rd[0] !== 1'b1);
        bus_write(REG_DATA, 32'h0000_0022);
        // rx_valid is still set from the first byte, so poll specifically for
        // the overrun flag once the second byte lands on the full buffer.
        begin
            automatic int timeout = 2000;
            do begin
                bus_read(REG_STATUS, rd);
                timeout--;
            end while (rd[2] !== 1'b1 && timeout > 0);
            if (timeout == 0) begin
                $display("FAIL  [T3 overrun] timed out");
                fail_count++;
            end
        end
        check("T3 overrun flagged", {31'h0, rd[2]}, 32'h1);
        bus_read(REG_DATA, rd);   // consume → clears overrun
        bus_read(REG_STATUS, rd);
        check("T3 overrun cleared after read", {31'h0, rd[2]}, 32'h0);

        $display("--------------------------------------------------");
        if (fail_count == 0) $display("PASS - all tests passed.");
        else                 $display("FAIL - %0d test(s) failed.", fail_count);
        $finish;
    end

endmodule
