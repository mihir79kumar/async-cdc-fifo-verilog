`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.06.2026 00:00:25
// Design Name: 
// Module Name: async_fifo
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
// FULL FLAG (clk_w domain):
//   Compared against synchronized rd_ptr_gray. Conservative - may assert
//   1-2 cycles early. SAFE: never overflows.
//
// EMPTY FLAG (clk_r domain):
//   rd_ptr_gray == wr_ptr_gray_sync. Conservative - may de-assert late.
//   SAFE: never reads garbage.
//
// data_out is REGISTERED (clocked by clk_r):
//   Captures mem[rd_ptr] on the same edge rd_ptr increments.
//   Holds the valid byte for a full cycle - easy to sample downstream.
//////////////////////////////////////////////////////////////////////////////////

module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 3,
    parameter PTR_WIDTH  = ADDR_WIDTH + 1
)(
    // Write domain
    input                   clk_w,
    input                   rst_w,
    input                   wr_en,
    input  [DATA_WIDTH-1:0] data_in,
    output                  full,

    // Read domain
    input                   clk_r,
    input                   rst_r,
    input                   rd_en,
    output [DATA_WIDTH-1:0] data_out,
    output                  empty
);

    // ?? Shared memory ??????????????????????????????????????????????????
    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    // ?? Write domain: binary pointer ???????????????????????????????????
    reg  [PTR_WIDTH-1:0] wr_ptr_bin;
    wire [PTR_WIDTH-1:0] wr_ptr_gray;

    always @(posedge clk_w or posedge rst_w) begin
        if (rst_w)
            wr_ptr_bin <= {PTR_WIDTH{1'b0}};
        else if (wr_en && !full) begin
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= data_in;
            wr_ptr_bin <= wr_ptr_bin + 1'b1;
        end
    end

    // ?? Read domain: binary pointer + registered data_out ?????????????
    // data_out is registered: on the clk_r edge where rd_en is asserted,
    // we capture mem[rd_ptr] into data_out_reg BEFORE advancing rd_ptr.
    // This means data_out is stable for a full cycle after the read -
    // no combinational glitch, easy to sample in mod_b and testbench.
    reg [PTR_WIDTH-1:0]  rd_ptr_bin;
    wire [PTR_WIDTH-1:0] rd_ptr_gray;
    reg [DATA_WIDTH-1:0] data_out_reg;

    always @(posedge clk_r or posedge rst_r) begin
        if (rst_r) begin
            rd_ptr_bin   <= {PTR_WIDTH{1'b0}};
            data_out_reg <= {DATA_WIDTH{1'b0}};
        end else if (rd_en && !empty) begin
            data_out_reg <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]]; // capture first
            rd_ptr_bin   <= rd_ptr_bin + 1'b1;               // then advance
        end
    end

    assign data_out = data_out_reg;

    // ?? Gray encode both pointers ??????????????????????????????????????
    gray_enc #(.WIDTH(PTR_WIDTH)) u_gray_wr (
        .bin  (wr_ptr_bin),
        .gray (wr_ptr_gray)
    );

    gray_enc #(.WIDTH(PTR_WIDTH)) u_gray_rd (
        .bin  (rd_ptr_bin),
        .gray (rd_ptr_gray)
    );

    // ?? Sync wr_ptr_gray ? clk_r domain (for EMPTY) ???????????????????
    wire [PTR_WIDTH-1:0] wr_ptr_gray_sync;

    sync_2ff #(.WIDTH(PTR_WIDTH)) u_sync_wr2r (
        .clk (clk_r),
        .rst (rst_r),
        .d   (wr_ptr_gray),
        .q   (wr_ptr_gray_sync)
    );

    // ?? Sync rd_ptr_gray ? clk_w domain (for FULL) ????????????????????
    wire [PTR_WIDTH-1:0] rd_ptr_gray_sync;

    sync_2ff #(.WIDTH(PTR_WIDTH)) u_sync_rd2w (
        .clk (clk_w),
        .rst (rst_w),
        .d   (rd_ptr_gray),
        .q   (rd_ptr_gray_sync)
    );

    // ?? FULL: evaluated in clk_w domain ???????????????????????????????
    // Cummings (SNUG 2002) formula:
    // MSB and second MSB of Gray pointers differ, rest equal ? full
    assign full = (wr_ptr_gray[PTR_WIDTH-1]   != rd_ptr_gray_sync[PTR_WIDTH-1]) &&
                  (wr_ptr_gray[PTR_WIDTH-2]   != rd_ptr_gray_sync[PTR_WIDTH-2]) &&
                  (wr_ptr_gray[PTR_WIDTH-3:0] == rd_ptr_gray_sync[PTR_WIDTH-3:0]);

    // ?? EMPTY: evaluated in clk_r domain ??????????????????????????????
    assign empty = (rd_ptr_gray == wr_ptr_gray_sync);

endmodule