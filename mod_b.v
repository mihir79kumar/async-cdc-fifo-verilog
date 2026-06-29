`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.06.2026 00:08:21
// Design Name: 
// Module Name: mod_b
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
// FIXES over original mod_b:
//   1. rd_en is now a REGISTERED output (was combinational ? glitchy).
//      Combinational rd_en in original caused glitches and only pulsed
//      for one combinational phase, not a clean clock-edge pulse.
//   2. default branch added to case statement - original had no default,
//      which causes LATCH INFERENCE in synthesis.
//   3. FSM outputs (rd_en) driven from the registered next-state,
//      not from combinational always block.
//
// FSM STATES:
//   IDLE       ? wait one cycle (pipeline setup)
//   WAIT       ? check empty flag, don't read yet
//   READ       ? assert rd_en for one cycle, capture data
//
// BEHAVIOUR:
//   Cycles through IDLE?WAIT?READ continuously.
//   Only reads when FIFO is not empty.
//   data_out holds last valid data when FIFO goes empty.
//////////////////////////////////////////////////////////////////////////////////

module mod_b (
    input        clk_r,      // read domain clock (75 MHz)
    input        rst,        // async reset
    input        empty,      // from async_fifo - don't read when asserted
    input  [7:0] data_in,    // data from async_fifo
    output reg   rd_en,      // read enable to FIFO
    output reg [7:0] data_out
);

    // FSM state encoding
    localparam IDLE = 2'b00;
    localparam WAIT = 2'b01;
    localparam READ = 2'b10;

    reg [1:0] state;

    // ?? Single always block: registered FSM + registered outputs ??
    // Putting next-state AND output in one clocked block guarantees
    // rd_en is a registered (glitch-free) signal.
    always @(posedge clk_r or posedge rst) begin
        if (rst) begin
            state    <= IDLE;
            rd_en    <= 1'b0;
            data_out <= 8'h00;
        end else begin
            // Default: deassert rd_en unless in READ state
            rd_en <= 1'b0;

            case (state)
                IDLE: begin
                    // One pipeline bubble - let FIFO settle after reset
                    state <= WAIT;
                end

                WAIT: begin
                    if (!empty)
                        state <= READ;   // data available - go read
                    else
                        state <= WAIT;   // still empty - keep waiting
                end

                READ: begin
                    if (!empty) begin
                        rd_en    <= 1'b1;          // assert read enable
                        data_out <= data_in;        // latch incoming data
                    end
                    state <= WAIT;  // always go back to WAIT after one read
                end

                default: begin
                    // Catches any illegal state - prevents latch
                    state <= IDLE;
                    rd_en <= 1'b0;
                end
            endcase
        end
    end

endmodule