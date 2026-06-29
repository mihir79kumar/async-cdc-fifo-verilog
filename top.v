`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.06.2026 00:10:57
// Design Name: 
// Module Name: top
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
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// CLOCK DOMAINS:
//   clk_w - 50 MHz  - write side (mod_a produces data here)
//   clk_r - 75 MHz  - read side  (mod_b consumes data here)
//
//   In hardware these come from separate MMCM/PLL outputs or external sources.
//   In simulation the testbench generates both independently.
//
// SIGNAL FLOW:
//   mod_a ? [data_in, wr_en] ? async_fifo ? [data_out, rd_en] ? mod_b
//
//   full  feeds back from async_fifo ? mod_a  (write domain)
//   empty feeds back from async_fifo ? mod_b  (read domain)
//////////////////////////////////////////////////////////////////////////////////

module top (
    input        clk_w,         // 50 MHz write clock
    input        clk_r,         // 75 MHz read clock
    input        rst,           // global async reset (both domains)
    output [7:0] data_out_top,  // final consumer output
    // Debug/observation outputs (connect to LEDs or ILA in hardware)
    output       full,
    output       empty
);

    // ?? Interconnect wires ??????????????????????????????????????????????
    wire [7:0] prod_to_fifo;   // mod_a data  ? async_fifo data_in
    wire       wr_en;          // mod_a wr_en ? async_fifo wr_en
    wire [7:0] fifo_to_cons;   // async_fifo data_out ? mod_b data_in
    wire       rd_en;          // mod_b rd_en ? async_fifo rd_en

    // ?? Producer: mod_a (clk_w domain) ?????????????????????????????????
    mod_a u_mod_a (
        .clk_w    (clk_w),
        .rst      (rst),
        .full     (full),         // back-pressure from FIFO
        .wr_en    (wr_en),
        .data_out (prod_to_fifo)
    );

    // ?? CDC FIFO (dual clock) ???????????????????????????????????????????
    async_fifo #(
        .DATA_WIDTH (8),
        .ADDR_WIDTH (3),
        .PTR_WIDTH  (4)
    ) u_fifo (
        // Write domain
        .clk_w   (clk_w),
        .rst_w   (rst),
        .wr_en   (wr_en),
        .data_in (prod_to_fifo),
        .full    (full),
        // Read domain
        .clk_r   (clk_r),
        .rst_r   (rst),
        .rd_en   (rd_en),
        .data_out(fifo_to_cons),
        .empty   (empty)
    );

    // ?? Consumer: mod_b (clk_r domain) ?????????????????????????????????
    mod_b u_mod_b (
        .clk_r    (clk_r),
        .rst      (rst),
        .empty    (empty),        // back-pressure from FIFO
        .data_in  (fifo_to_cons),
        .rd_en    (rd_en),
        .data_out (data_out_top)
    );

endmodule