`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/23/2021 10:38:42 PM
// Design Name: 
// Module Name: adder_tree
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


module adder_tree #(
    parameter NUM_TOT_ELEMENT   		= 8,
	parameter RANK_FACTOR_MATRIX        = 16,
    parameter N                 		= 32
)
(
    clk,
    rst,
	in_avl,
    adder_inputs,
	out_avl,
	c
    );

localparam 						DATA_LEN = N;




	function integer log2;
		input integer value;
		begin
			value = value-1;
			
			for(log2=0; value>0; log2=log2+1)
				value = value>>1;
		end
	endfunction

	function integer num_wire_add;
		input integer NUM_ELEMENT;

		begin
			integer i,j,TEMP;
			num_wire_add = 0;
			for(i=0; i<NUM_ELEMENT; i=i+1) begin: LOGIC1
				num_wire_add = (num_wire_add + len_add_zero_input(i+1));

			end

			num_wire_add = num_wire_add +1;
		end
	endfunction


	function integer len_add_zero_input;
		input integer NUM_ELEMENT;

		begin
			integer i;
			len_add_zero_input = 1;
			for(i=0; i<NUM_ELEMENT; i=i+1) begin
				len_add_zero_input = len_add_zero_input*2;
			end
		end
	endfunction

	function integer power2;
		input integer x;
		begin
			integer i;
			power2 = 1;

			for(i=0; i<x; i=i+1) begin
				power2 = power2*2;
			end			

		end
	
	endfunction

input   wire                                                                                        clk;
input   wire                                                                                        rst;
input   wire   	[NUM_TOT_ELEMENT-1 : 0][RANK_FACTOR_MATRIX-1 : 0][DATA_LEN-1 :0]                    adder_inputs;
input 	wire  																						in_avl;
output 	reg  																						out_avl;
output 	reg 	[RANK_FACTOR_MATRIX-1 : 0][N-1 : 0]													c;

genvar add_i,add_k,add_w;
integer count_x;

wire   	[num_wire_add(log2(NUM_TOT_ELEMENT))-1 : 0][RANK_FACTOR_MATRIX-1 : 0][DATA_LEN-1 :0]                          wires_for_add;
wire   	[num_wire_add(log2(NUM_TOT_ELEMENT))-1 : 0]                          										  set_of_valids;
wire  	[len_add_zero_input(log2(NUM_TOT_ELEMENT))-1 : 0] 															  initial_valids;

assign c = wires_for_add[num_wire_add(log2(NUM_TOT_ELEMENT))-1];
assign out_avl = set_of_valids[num_wire_add(log2(NUM_TOT_ELEMENT))-1];

assign initial_valids = {(len_add_zero_input(log2(NUM_TOT_ELEMENT))){in_avl}};


assign wires_for_add[len_add_zero_input(log2(NUM_TOT_ELEMENT))-1 : 0] = {adder_inputs,{((len_add_zero_input(log2(NUM_TOT_ELEMENT))-NUM_TOT_ELEMENT)*DATA_LEN){1'b0}}};
assign set_of_valids[len_add_zero_input(log2(NUM_TOT_ELEMENT))-1 : 0] = {initial_valids,{((len_add_zero_input(log2(NUM_TOT_ELEMENT))-NUM_TOT_ELEMENT)){1'b0}}};

generate

for(add_i=log2(NUM_TOT_ELEMENT); add_i>0; add_i=add_i-1 ) begin : ADDER_ELEMENT_GENERATION
	for(add_k=0; add_k<len_add_zero_input(add_i); add_k=add_k+2) begin : ADDER_INST
		qadd #(.N(N)) inst_qadd (.clk(clk), .rst(rst), .in_avl0(set_of_valids[(add_k+num_wire_add(log2(NUM_TOT_ELEMENT))-num_wire_add(add_i))]), .in_avl1(set_of_valids[(add_k+num_wire_add(log2(NUM_TOT_ELEMENT))-num_wire_add(add_i)+1)]), .out_avl(set_of_valids[add_k/2+num_wire_add(log2(NUM_TOT_ELEMENT))-num_wire_add(add_i-1)]), .a(wires_for_add[(add_k+num_wire_add(log2(NUM_TOT_ELEMENT))-num_wire_add(add_i))]), .b(wires_for_add[(add_k+num_wire_add(log2(NUM_TOT_ELEMENT))-num_wire_add(add_i)+1)]), .c(wires_for_add[add_k/2+num_wire_add(log2(NUM_TOT_ELEMENT))-num_wire_add(add_i-1)]));
	end
end

endgenerate

endmodule
