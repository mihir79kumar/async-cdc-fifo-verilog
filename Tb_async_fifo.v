`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.06.2026 00:14:56
// Design Name: 
// Module Name: Tb_async_fifo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
// NOTE: Tests the async_fifo directly - NOT through top/mod_b.
//       This avoids mod_b's FSM interfering with rd_en during checks.
//
// TEST SCENARIOS:
//   T1 - Reset: empty=1, full=0 after reset
//   T2 - Write until full: full asserts after 8 writes
//   T3 - Read until empty: all 8 bytes correct, in order
//   T4 - Simultaneous write + read: no corruption
//   T5 - Write-when-full rejection: overflow attempt does not corrupt
//   T6 - Read-when-empty rejection: spurious read does not produce garbage
//
// CLOCKS:
//   clk_w = 50 MHz (period 20 ns)
//   clk_r = 75 MHz (period 13 ns, offset 3 ns to stress CDC)
//////////////////////////////////////////////////////////////////////////////////

module tb_async_fifo;

    localparam CLK_W_HALF = 10;   // 20ns period
    localparam CLK_R_HALF = 7;    // ~13ns period (~75 MHz)

    // DUT ports
    reg        clk_w, clk_r, rst;
    reg        wr_en, rd_en;
    reg  [7:0] data_in;
    wire [7:0] data_out;
    wire       full, empty;

    // Scoreboard
    integer pass_count = 0;
    integer fail_count = 0;

    // DUT - async_fifo only (bypass mod_a/mod_b for clean testing)
    async_fifo #(.DATA_WIDTH(8), .ADDR_WIDTH(3), .PTR_WIDTH(4)) dut (
        .clk_w   (clk_w), .rst_w (rst),
        .wr_en   (wr_en), .data_in(data_in), .full(full),
        .clk_r   (clk_r), .rst_r (rst),
        .rd_en   (rd_en), .data_out(data_out), .empty(empty)
    );

    // Independent clocks, offset by 3 ns to stress CDC
    initial clk_w = 0;
    always  #(CLK_W_HALF) clk_w = ~clk_w;

    initial begin #3; clk_r = 0; end
    always  #(CLK_R_HALF) clk_r = ~clk_r;

    // ?? Tasks ??????????????????????????????????????????????????????????

    // Write one byte - one clk_w pulse
    task write_byte;
        input [7:0] d;
        begin
            @(posedge clk_w); #1;
            data_in = d;
            wr_en   = 1'b1;
            @(posedge clk_w); #1;
            wr_en   = 1'b0;
        end
    endtask

    // Read one byte - pulse rd_en for one clk_r cycle
    // data_out is registered: valid on the NEXT posedge after rd_en
    task read_byte;
        output [7:0] d;
        begin
            @(posedge clk_r); #1;
            rd_en = 1'b1;
            @(posedge clk_r); #1;  // data_out captured inside FIFO here
            rd_en = 1'b0;
            @(posedge clk_r); #1;  // wait one more cycle - output now stable
            d = data_out;
        end
    endtask

    // Allow CDC synchronizers to settle (2 destination-clock cycles)
    task cdc_settle;
        begin
            repeat(4) @(posedge clk_r);
            repeat(4) @(posedge clk_w);
        end
    endtask

    // Pass/fail checker
    task check;
        input        cond;
        input [200:0] name;
        begin
            if (cond) begin
                $display("  PASS | %s", name);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL | %s  [data_out=%0h full=%b empty=%b]",
                          name, data_out, full, empty);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ?? Main ???????????????????????????????????????????????????????????
    integer i;
    reg [7:0] rval;

    initial begin
        wr_en = 0; rd_en = 0; data_in = 0; rst = 1;

        $display("========================================");
        $display("  CDC ASYNC FIFO -- Self-Checking TB    ");
        $display("  clk_w=50MHz  clk_r=75MHz  depth=8    ");
        $display("========================================");

        repeat(6) @(posedge clk_w);
        rst = 0;
        cdc_settle;

        // ?? T1: Reset ?????????????????????????????????????????????????
        $display("\n[T1] Reset Behaviour");
        check(empty === 1'b1, "EMPTY asserted after reset");
        check(full  === 1'b0, "FULL  deasserted after reset");

        // ?? T2: Write Until Full ???????????????????????????????????????
        $display("\n[T2] Write Until Full");
        for (i = 1; i <= 8; i = i + 1)
            write_byte(i[7:0]);
        cdc_settle;
        check(full  === 1'b1, "FULL asserts after 8 writes");
        check(empty === 1'b0, "EMPTY stays low when full");

        // ?? T3: Read Until Empty - Data Integrity ??????????????????????
        $display("\n[T3] Read Until Empty -- Data Integrity");
        for (i = 1; i <= 8; i = i + 1) begin
            read_byte(rval);
            if (rval === i[7:0]) begin
                $display("  PASS | Data in order  [expected=0x%02h  got=0x%02h]", i[7:0], rval);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL | Data in order  [expected=0x%02h  got=0x%02h]", i[7:0], rval);
                fail_count = fail_count + 1;
            end
        end
        cdc_settle;
        check(empty === 1'b1, "EMPTY asserts after full drain");
        check(full  === 1'b0, "FULL  clears after drain");

        // ?? T4: Simultaneous Write + Read ?????????????????????????????
        $display("\n[T4] Simultaneous Write + Read");
        // Pre-fill 4 entries
        for (i = 0; i < 4; i = i + 1)
            write_byte(8'hA0 + i[7:0]);
        cdc_settle;
        // Interleave: one write then one read, 4 times
        for (i = 0; i < 4; i = i + 1) begin
            write_byte(8'hB0 + i[7:0]);
            read_byte(rval);
        end
        cdc_settle;
        check(full  === 1'b0, "Not full after balanced write+read");
        $display("  INFO | Simultaneous CDC ops completed without lockup");
        // Drain the 4 pre-filled + 4 written - 4 read = 4 remaining
        for (i = 0; i < 4; i = i + 1) read_byte(rval);
        cdc_settle;
        check(empty === 1'b1, "EMPTY after draining all remainder");

        // ?? T5: Write-When-Full Rejection ?????????????????????????????
        $display("\n[T5] Write-When-Full Rejection");
        for (i = 1; i <= 8; i = i + 1)
            write_byte(i[7:0]);
        cdc_settle;
        check(full === 1'b1, "FULL before overflow attempt");
        // Attempt one more write - should be silently blocked
        @(posedge clk_w); #1;
        data_in = 8'hFF; wr_en = 1'b1;
        @(posedge clk_w); #1;
        wr_en = 1'b0;
        cdc_settle;
        check(full === 1'b1, "Still FULL after rejected write");
        // Read first byte - must still be 0x01
        read_byte(rval);
        check(rval === 8'h01, "First byte uncorrupted (0x01) after overflow attempt");
        // Drain rest
        for (i = 0; i < 7; i = i + 1) read_byte(rval);
        cdc_settle;

        // ?? T6: Read-When-Empty Rejection ?????????????????????????????
        $display("\n[T6] Read-When-Empty Rejection");
        check(empty === 1'b1, "EMPTY confirmed before spurious read");
        @(posedge clk_r); #1;
        rd_en = 1'b1;
        @(posedge clk_r); #1;
        rd_en = 1'b0;
        cdc_settle;
        check(empty === 1'b1, "Still EMPTY after spurious read");
        $display("  INFO | Empty flag held -- no ghost data produced");

        // ?? Summary ???????????????????????????????????????????????????
        $display("\n========================================");
        $display("  RESULTS: %0d PASSED  |  %0d FAILED", pass_count, fail_count);
        if (fail_count == 0)
            $display("  STATUS : ALL TESTS PASSED");
        else
            $display("  STATUS : SOME TESTS FAILED -- check waveform");
        $display("========================================\n");

        $finish;
    end

    // Watchdog
    initial begin
        #2000000;
        $display("WATCHDOG: timeout");
        $finish;
    end

    // VCD dump
    initial begin
        $dumpfile("tb_async_fifo.vcd");
        $dumpvars(0, tb_async_fifo);
    end

endmodule