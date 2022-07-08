`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Research
// Engineer: Sasindu Wijeratne
// 
// Create Date: 11/06/2017 09:11:57 PM
// Design Name: 
// Module Name: MACC_convo_unit
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


module MACC_convo_unit(
	clk, 
	input_array_1, 
	input_array_2, 
	bias_in,
	output_element
    );

	parameter   Q            	=  15;
	parameter   N            	=  32;
	parameter DATA_LEN       	=  N;
	parameter ARRAY_WIDTH    	=  3;
	parameter NUM_TOT_ELEMENT   =  ARRAY_WIDTH*ARRAY_WIDTH;
	parameter NUM_WIRE_LINES 	= NUM_TOT_ELEMENT + ARRAY_WIDTH;



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



input 	wire 												clk; 
input 	wire 	[NUM_TOT_ELEMENT-1 : 0][DATA_LEN-1 : 0] 	input_array_1;
input 	wire 	[NUM_TOT_ELEMENT-1 : 0][DATA_LEN-1 : 0] 	input_array_2;
input 	wire 	[DATA_LEN-1 : 0]							bias_in;
output  wire 	[DATA_LEN-1 : 0]							output_element;

wire 			[NUM_TOT_ELEMENT-1 : 0][DATA_LEN-1 : 0] 						mul_unit_out_non_reg;
reg 			[NUM_TOT_ELEMENT-1 : 0][DATA_LEN-1 : 0] 						mul_unit_out=0;
wire 			[num_wire_add(log2(NUM_TOT_ELEMENT))-1 : 0][DATA_LEN-1 :0]		wires_for_add;
wire 			[DATA_LEN-1 : 0]												neural_element;


//assign wires_for_add[0 : len_add_zero_input(log2(NUM_TOT_ELEMENT))-1] = {mul_unit_out,{((len_add_zero_input(log2(NUM_TOT_ELEMENT))-NUM_TOT_ELEMENT)*DATA_LEN){1'b0}};
assign wires_for_add[len_add_zero_input(log2(NUM_TOT_ELEMENT))-1 : 0] = {mul_unit_out,{((len_add_zero_input(log2(NUM_TOT_ELEMENT))-NUM_TOT_ELEMENT)*DATA_LEN){1'b0}}};

/*always@(posedge clk) begin
		mul_unit_out = #1 mul_unit_out_non_reg;
end*/
always@(*) begin
		mul_unit_out = mul_unit_out_non_reg;
end


genvar add_i,add_k,add_w;
integer count_x;
 
generate

for(add_w=0; add_w<NUM_TOT_ELEMENT; add_w = add_w+1) begin : MULTIPLICATION_UNIT_GENERATION
		qmult #(
			.Q(Q),
			.N(N)
		) inst_qmult (
			.i_multiplicand (input_array_1[add_w]),
			.i_multiplier   (input_array_2[add_w]),
			.o_result       (mul_unit_out_non_reg[add_w]),
			.ovr            ()
		);
end

for(add_i=log2(NUM_TOT_ELEMENT); add_i>0; add_i=add_i-1 ) begin : ADDER_ELEMENT_GENERATION

	for(add_k=0; add_k<len_add_zero_input(add_i); add_k=add_k+2) begin : ADDER_INST
			qadd #(
				.Q(Q), .N(N)) inst_qadd (.a(wires_for_add[(add_k+num_wire_add(log2(NUM_TOT_ELEMENT))-num_wire_add(add_i))]), .b(wires_for_add[(add_k+num_wire_add(log2(NUM_TOT_ELEMENT))-num_wire_add(add_i)+1)]), .c(wires_for_add[add_k/2+num_wire_add(log2(NUM_TOT_ELEMENT))-num_wire_add(add_i-1)]));
	end
end

endgenerate

qadd #(
		.Q(Q), .N(N)) bias_qadd(.a(wires_for_add[num_wire_add(log2(NUM_TOT_ELEMENT))-1]), .b(bias_in), .c(neural_element)
		);

assign output_element = neural_element[DATA_LEN-1] ? 0 : neural_element;


endmodule
