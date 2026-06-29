`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.06.2026 00:07:11
// Design Name: 
// Module Name: mod_a
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
// FIXES over original mod_a:
//   1. wr_en is now GATED on !full - original always asserted wr_en=1,
//      which means it tried to write even when FIFO was full.
//   2. data_out is a registered output - clean, glitch-free.
//   3. Data counter increments only on a successful write.
//
// BEHAVIOUR:
//   After reset, starts counting from 0x01.
//   Every clock cycle where FIFO is not full ? write current byte, increment.
//   When FIFO is full ? hold, wait, resume when space is available.
//////////////////////////////////////////////////////////////////////////////////

module mod_a (
    input        clk_w,     // write domain clock (50 MHz)
    input        rst,       // async reset
    input        full,      // from async_fifo - stop writing when asserted
    output reg   wr_en,     // write enable to FIFO
    output reg [7:0] data_out  // data to FIFO
);

    reg [7:0] counter;  // tracks next byte value to send

    always @(posedge clk_w or posedge rst) begin
        if (rst) begin
            counter  <= 8'h01;
            data_out <= 8'h00;
            wr_en    <= 1'b0;
        end else begin
            if (!full) begin
                // FIFO has space - write current counter value
                data_out <= counter;
                wr_en    <= 1'b1;
                counter  <= counter + 1'b1;  
            end else begin
                // FIFO full - pause, do not assert wr_en
                wr_en    <= 1'b0;
                // data_out and counter hold their values (no increment)
            end
        end
    end

endmodule
