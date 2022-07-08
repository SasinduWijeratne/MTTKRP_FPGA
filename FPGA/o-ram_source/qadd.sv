`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/24/2021 01:05:27 PM
// Design Name: 
// Module Name: qadd
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


module qadd #(
    parameter RANK_FACTOR_MATRIX        = 16,
	parameter N                         = 32
	)(
    input  wire                                             clk,
    input  wire                                             rst,
    input  wire                                             in_avl0,
    input  wire                                             in_avl1,
    input  wire     [RANK_FACTOR_MATRIX-1 : 0][N-1:0]       a,
    input  wire     [RANK_FACTOR_MATRIX-1 : 0][N-1:0]       b,
    output reg                                              out_avl,
    output reg      [RANK_FACTOR_MATRIX-1 : 0][N-1:0]       c
    );

wire                            in_avl;

integer i;
genvar j;

generate
     for (j= 0; j < RANK_FACTOR_MATRIX; j = j+1) begin: ADDER_SET
         c_addsub_0 uut_add (
            .A(a[j]),
            .B(b[j]),
            .CLK(clk),
            .CE(in_avl0&in_avl1),
            .S(c[j])
          );        
     end
endgenerate

assign in_avl = in_avl0&in_avl1;

    always @(posedge clk) begin
        if(~rst) begin
            out_avl     <= 0;
        end else begin
            out_avl         <= in_avl;
        end
        
    end

endmodule

 module c_addsub(CLK, A, B, CE, S);
parameter w = 32;

input CLK, CE;
input [w-1:0] A,B;
output reg [w-1:0] S;


always @(posedge CLK) begin
    if(CE) begin
        S = A * B;
    end
end

endmodule  

