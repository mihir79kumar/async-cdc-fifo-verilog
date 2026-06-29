`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.06.2026 00:03:32
// Design Name: 
// Module Name: grey_enc
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
//   The FIFO pointer must cross clock domains.
//   Binary counting changes multiple bits at once (e.g. 3->4 = 0b0011->0b0100,
//   3 bits flip). If the 2-FF synchronizer samples mid-transition, it sees garbage.
//   Gray code changes exactly 1 bit per count, so the worst case is
//   seeing the previous or next valid pointer - never an invalid value.
//
// Parameters  : WIDTH - pointer width in bits (default 4)
//////////////////////////////////////////////////////////////////////////////////

module gray_enc #(parameter WIDTH = 4)(
    input  [WIDTH-1:0] bin,   // binary pointer in
    output [WIDTH-1:0] gray   // gray coded pointer out
);
    
    assign gray = bin ^ (bin >> 1);

endmodule
