`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.06.2026 00:05:45
// Design Name: 
// Module Name: sync_2ff
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
// WHY THIS EXISTS:
//   When a signal crosses from one clock domain to another, the receiving
//   flip-flop may go METASTABLE (output stuck between 0 and 1) if the
//   signal changes near the clock edge.
//
//   The fix: chain two flip-flops on the receiving clock.
//     FF1 may go metastable, but has a full clock period to resolve.
//     FF2 samples FF1's output - by then it is statistically guaranteed
//     to be a clean 0 or 1. (Probability of residual metastability ~10^-15)
//
//   Used TWICE in async_fifo:
//     1. wr_ptr_gray  crosses from clk_w into clk_r domain
//     2. rd_ptr_gray  crosses from clk_r into clk_w domain
//
// Parameters  : WIDTH - bus width (matches gray_enc WIDTH = 4)
//////////////////////////////////////////////////////////////////////////////////

module sync_2ff #(parameter WIDTH = 4)(
    input              clk,        // destination domain clock
    input              rst,        // async reset
    input  [WIDTH-1:0] d,          // input from source domain
    output [WIDTH-1:0] q           // safe synchronized output
);
    reg [WIDTH-1:0] ff1, ff2;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ff1 <= {WIDTH{1'b0}};
            ff2 <= {WIDTH{1'b0}};
        end else begin
            ff1 <= d;    // FF1: may go metastable - never use this directly
            ff2 <= ff1;  // FF2: samples resolved FF1 output - safe to use
        end
    end

    assign q = ff2;  // only FF2 output is exposed to logic

endmodule
