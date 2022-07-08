`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: pgroup @ usc
// Engineer: Sasindu Wijeratne
// 
// Create Date: 06/22/2020 12:00:48 PM
// Design Name: 
// Module Name: forwarding_unit_wrapper
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

/*

Cache Read Request			
Bit(s)	Width	Function	Definition
607		1		Valid		'1'=There is a flit present and ready to be received.
606		1		Tail		‘1’=Designation of tail flit, final flit in transmission
605:591	15		Spare1	
590:584	7		SRC_Dest	Node # of flit source (for Cheetah->FPGA) or dest (for FPGA->Cheetah). CHEETAH Cores(0-79), IntCore(80), 
583:581	3		Spare2	
580:576	5		Msg_type	Message type designation, See Word document for Designations
575		1		Spare3	
574:568	7		SLOT_ID		Port Binding Slot ID. This is a port associated for this request. Memory return has to include this port in this field.
567:561	7		Spare4	
560:556	5		TX_Count	[Number of flits in packet – 1]. NOT INCLUDING HEAD FLIT. i.e. 0=one flit, 
555		1		Head		1'=This is the header flit (first flit in transmission)
554:548	7		Spare	
547:512	36		Dram_addr	DRAM Address/Misc Status
511:0	512		Spare	
			
All Other DRAM interaction Flits			
Bit(s)	Width	Function	Definition
607		1		Valid		'1'=There is a flit present and ready to be received.
606		1		Tail		‘1’=Designation of tail flit, final flit in transmission
605:599	7		Dest		Node # of flit source (for Cheetah->FPGA) or dest (for FPGA->Cheetah).
598:591	8		Spare1	
590:584	7		SRC_Dest	Node # of flit source (for Cheetah->FPGA) or dest (for FPGA->Cheetah). CHEETAH Cores(0-79), IntCore(80), 
583:581	3		Spare2	
580:576	5		Msg_type	Message type designation, See Word document for Designations
575		1		Spare3	
574:568	7		SLOT_ID		Port Binding Slot ID. This is a port associated for this request. Memory return has to include this port in this field.
567:566	2		Spare4	
565:561	5		SEQ_NUM		Flit sequence number. N/A for Header flit, 0 for next flit, 1 for following flit, etc.
560:556	5		TX_Count	[Number of flits in packet – 1]. NOT INCLUDING HEAD FLIT. i.e. 0=one flit, 
555		1		Head		1'=This is the header flit (first flit in transmission)
554:548	7		PKT_Count	# of Packets(32 flit counts)-If field is 1, then there is 32 Flits + #flits in Flit_Count field
547:512	36		Dram_addr	DRAM Address/Misc Status
511:0	512		Payload		Data Payload 

*/

module forwarding_unit_wrapper_dma #(
parameter 	LEN_ADDR 			=	 32,
parameter 	LEN_PROCESSOR_NO 	= 	  7,
parameter   LEN_SLOT_ID         =     7,
parameter   PACKT_LEN           =     13,
parameter 	LEN_DATA_LHS 		= 	608,
parameter 	LEN_DATA_RHS 		= 	512,
parameter 	RHS_BURST_LEN 		= 	1
	)
	(

input 	wire 										clk,
input 	wire 										rst,

// Input from the scheduler
input 	wire 	[LEN_PROCESSOR_NO-1: 0] 			sc_in_processor_id,
input 	wire 	[LEN_SLOT_ID-1: 0] 			        sc_in_slot_id,
input 	wire 	[LEN_DATA_RHS-1: 0] 				sc_in_data,
input 	wire 	[LEN_ADDR-1: 0] 					sc_in_addr,
input 	wire 					 					sc_in_ready_to_send,
input 	wire 										sc_in_data_ready_for_fu,

//Input from DMA
input 	wire 	[LEN_PROCESSOR_NO-1: 0] 			dma_in_processor_id,
input 	wire 	[LEN_DATA_RHS-1: 0] 				dma_in_data,
input 	wire 	[LEN_ADDR-1: 0] 					dma_in_addr,
input 	wire 										dma_in_data_ready_for_fu,
input 	wire    [PACKT_LEN-1 : 0]                   dma_in_tx_count,
input 	wire 	[LEN_SLOT_ID-1: 0] 			        dma_in_slot_id,

// Input from the LHS
input 	wire 					 					LHS_in_ready_to_receive, // LHS is accepting data

// Output to the scheduler
output 	reg 										ready_to_receive_sc,
output 	reg 										ready_to_receive_data_sc,

//Output to DMA
output 	reg 										dma_ready_to_receive_data,

// Output to the LHS
output 	reg 	[LEN_DATA_LHS-1: 0] 				out_lhs_data,
output  reg 										out_available_lhs

    );

localparam 		STATE_BITS 							= 2;

localparam 		STATE_IDLE 							= 0,
		 		STATE_WRITE							= 1,
		 		STATE_DONE					    	= 2,
				STATE_DMA 							= 3;

localparam 	LEN_FLIT_WIDTH 	= LEN_DATA_LHS,
			LEN_Valid 		= 1,
			LEN_Tail 		= 1,
			LEN_Dest 		= 7,
			LEN_Spare1		= 8,
			LEN_SRC_Dest 	= 7,
			LEN_Spare2 		= 3,
			LEN_Msg_type 	= 5,
			LEN_Spare3 		= 1,
//			LEN_SLOT_ID 	= 7,
			LEN_Spare4 		= 2,
			LEN_SEQ_NUM 	= 5,
			LEN_TX_Count 	= 5,
			LEN_Head 		= 1,
			LEN_PKT_Count 	= 7,
			LEN_Dram_addr 	= 36,
			LEN_TX_ABS_LEN  = LEN_TX_Count,
			LEN_Spare5 		= LEN_FLIT_WIDTH - (LEN_Valid + LEN_Tail + LEN_Dest + LEN_Spare1 + LEN_SRC_Dest + LEN_Spare2 + LEN_Msg_type + LEN_Spare3 + LEN_SLOT_ID + LEN_Spare4 + LEN_SEQ_NUM + LEN_TX_Count + LEN_Head + LEN_PKT_Count + LEN_Dram_addr);


localparam CHECK_AADR_LEN = (LEN_Dram_addr <= LEN_ADDR);

reg 	[LEN_Valid-1:0] 			Valid 		= 1;
reg 	[LEN_Tail-1:0] 				Tail  		= 1;
reg 	[LEN_Spare1-1:0] 			Spare1 		= 0;
reg 	[LEN_Spare2-1:0] 			Spare2 		= 0;
reg 	[LEN_Spare3-1:0] 			Spare3 		= 0;
reg 	[LEN_Spare4-1:0] 			Spare4		= 0;
reg 	[LEN_SEQ_NUM-1:0] 			SEQ_NUM 	= 0;
reg 	[LEN_Head-1:0] 				Head 		= 1;
reg 	[LEN_PKT_Count-1:0] 		PKT_Count 	= 0;
reg 	[LEN_Spare5-1:0] 			Spare5 		= 0;


wire 	[LEN_SRC_Dest-1 : 0] 						pid_wire;
reg 	[LEN_SRC_Dest-1 :0]             			msg_type = {{(LEN_SRC_Dest-4){1'd0}},4'd10};
reg 	[LEN_SRC_Dest-1 :0]             			msg_type_dma = {{(LEN_SRC_Dest-4){1'd0}},4'd6};
wire    [LEN_SLOT_ID-1 : 0]                         slot_id;
reg     [LEN_TX_Count-1 : 0]                        tx_count = 0;
wire 	[LEN_Dram_addr-1 : 0] 						mem_addr_wire;
wire 	[LEN_Dram_addr-1 : 0] 						mem_addr_wire_dma;

reg 	[STATE_BITS-1:0]							state = 0;
reg 	[LEN_TX_Count+4: 0] 						burst_send_counter = 0;

reg 	[LEN_TX_ABS_LEN + LEN_PKT_Count : 0] 		dma_tx_abs_cnt;
wire    [LEN_TX_ABS_LEN + LEN_PKT_Count : 0]        cache_tx_count;

reg 	[LEN_DATA_RHS-1: 0] 						reg_sc_in_data;
reg 	[LEN_DATA_RHS-1: 0] 						reg_dma_in_data;

assign cache_tx_count = 0;

assign pid_wire = sc_in_processor_id[LEN_SRC_Dest-1 : 0];
assign slot_id = sc_in_slot_id;

`ifdef CHECK_AADR_LEN
    assign mem_addr_wire = sc_in_addr[LEN_Dram_addr-1 : 0];
    assign mem_addr_wire_dma = dma_in_addr[LEN_Dram_addr-1 : 0];
`else
    assign mem_addr_wire = {{(LEN_Dram_addr-LEN_ADDR){1'b0}},sc_in_addr};
    assign mem_addr_wire_dma = {{(LEN_Dram_addr-LEN_ADDR){1'b0}},dma_in_addr};
`endif


always @(posedge clk) begin : proc_lhs_out
	if(~rst) begin
	
		state 							<=  STATE_IDLE;
		burst_send_counter 				<=  0;
		out_available_lhs 				<=  0;
		dma_tx_abs_cnt 					<= 0;
	end else begin
	
		out_available_lhs 				<=  0;
        if(LHS_in_ready_to_receive) begin
            if(dma_in_data_ready_for_fu) begin
                state 							<=  STATE_IDLE;
                out_available_lhs 				<=  1;
                reg_dma_in_data                 <= dma_in_data;
                dma_tx_abs_cnt 					<= (dma_in_tx_count << 2);
                out_lhs_data 					<= {Valid, Tail, dma_in_processor_id[LEN_SRC_Dest-1:0], Spare1, dma_in_processor_id[LEN_SRC_Dest-1:0], Spare2, msg_type_dma, Spare3, dma_in_slot_id, Spare4, SEQ_NUM, dma_in_tx_count, Head, PKT_Count, mem_addr_wire_dma, dma_in_data};
            end
            else if(sc_in_data_ready_for_fu) begin
                
                state 							<=  STATE_IDLE;
                out_available_lhs 				<=  1;
                out_lhs_data 					<=  {Valid, Tail, sc_in_processor_id[LEN_SRC_Dest-1:0], Spare1, sc_in_processor_id[LEN_SRC_Dest-1:0], Spare2, msg_type, Spare3, sc_in_slot_id, Spare4, SEQ_NUM, cache_tx_count, Head, PKT_Count, mem_addr_wire_dma, sc_in_data};
                reg_sc_in_data                  <= sc_in_data;
            end
        end
	end
end



always @(*) begin : proc_lhs_comb
	if(~rst) begin
		ready_to_receive_sc 			<=  0;
		ready_to_receive_data_sc 		<=  0;

		dma_ready_to_receive_data 		<= 0;


	end else begin

		ready_to_receive_sc 			<=  0;
		ready_to_receive_data_sc 		<=  0;

		dma_ready_to_receive_data 		<= 0;


        if(LHS_in_ready_to_receive) begin
            if(dma_in_data_ready_for_fu) begin
                dma_ready_to_receive_data       <= 1;
            end
            else if(sc_in_data_ready_for_fu) begin
                ready_to_receive_sc 			<=  1;
                ready_to_receive_data_sc        <=  1;
            end
        end
	end
end

endmodule
