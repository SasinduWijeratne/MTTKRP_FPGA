`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: pgroup @ usc
// Engineer: Sasindu Wijeratne
// 
// Create Date: 12/21/2020 07:37:40 PM
// Design Name: 
// Module Name: command_decoder_v2
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
560:556	5		TX_Count	[Number of flits in packet �" 1]. NOT INCLUDING HEAD FLIT. i.e. 0=one flit, 
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
560:556	5		TX_Count	[Number of flits in packet �" 1]. NOT INCLUDING HEAD FLIT. i.e. 0=one flit, 
555		1		Head		1'=This is the header flit (first flit in transmission)
554:548	7		PKT_Count	# of Packets(32 flit counts)-If field is 1, then there is 32 Flits + #flits in Flit_Count field
547:512	36		Dram_addr	DRAM Address/Misc Status
511:0	512		Payload		Data Payload 

*/

module command_decoder_dma #(
parameter 	LEN_ADDR 			=	 32,
parameter 	LEN_PROCESSOR_NO 	= 	  7,
parameter 	RHS_BURST_LEN 		= 	  4,
parameter   LEN_SLOT_ID         =     7,
parameter   PACKT_LEN           =    13,
parameter 	LEN_DATA_RHS 		= 	512,
parameter 	LEN_DATA_LHS 		= 	608
	)
(

input 	wire 										clk,
input 	wire 										rst,

//Input from scheduler
input 	wire 										sc_in_ready_to_receive,

//Input from dma
input 	wire 										dma_in_ready_to_receive,

// Input from the LHS
input 	wire 	[LEN_DATA_LHS-1: 0] 				in_lhs_data,
input  wire											in_available_lhs,

//Output to scheduler
output 	reg 	[LEN_ADDR-1: 0] 					out_addr_sc,
output 	reg 	[LEN_PROCESSOR_NO-1: 0] 			out_processor_id_sc,
output 	reg 	[LEN_DATA_RHS-1: 0] 				out_data_sc,
output 	wire 					 					out_rd_enbl_sc,
output 	reg 					 					out_wr_enbl_sc,
output 	reg 					 					out_wr_enbl_data_sc,
output  reg     [LEN_SLOT_ID-1 : 0]                 out_slot_id_sc,

//Output to dma
output 	reg 	[LEN_ADDR-1: 0] 					out_addr_dma,
output 	reg 	[LEN_PROCESSOR_NO-1: 0] 			out_processor_id_dma,
output  reg     [LEN_SLOT_ID-1 : 0]                 out_slot_id_dma,
output  wire    [PACKT_LEN-1 : 0]                  	out_pkt_size_dma,
output 	reg 	[LEN_DATA_RHS-1: 0] 				out_data_dma,
output 	reg 					 					out_wr_enbl_dma,
output 	reg 					 					out_addr_dma_en,
output 	reg 					 					out_addr_dma_ctrl_en,
output 	reg 					 					out_data_dma_en,

// Output to the LHS
output 	wire 					 					out_ready_to_send_lhs, // assuming a fifo interface (first word fall through FIFO) -> read enable
output  wire                                        out_cd_avl_receive

    );

localparam 		STATE_BITS 							= 2;

//states
localparam 		STATE_IDLE 							= 0,
				STATE_PAYLOAD_MRP					= 1,
				STATE_READ_DMA 						= 2,
				STATE_WRITE_DMA 					= 3;

// FLIT Definitions
// localparam     LEN_MSG_TYPE                         = 5;
// localparam     LEN_SRC_DST                          = 7;

// localparam     LEN_PKT_COUNT                        = 8;
// localparam     LEN_TX_COUNT                         = 5+LEN_PKT_COUNT;
// localparam     LEN_SPARE_1                          = 32;
// localparam     LEN_SPARE_2                          = 28;
// localparam     LEN_DRAM_ADDR                        = 36;

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
			LEN_Spare5 		= LEN_FLIT_WIDTH - (LEN_Valid + LEN_Tail + LEN_Dest + LEN_Spare1 + LEN_SRC_Dest + LEN_Spare2 + LEN_Msg_type + LEN_Spare3 + LEN_SLOT_ID + LEN_Spare4 + LEN_SEQ_NUM + LEN_TX_Count + LEN_Head + LEN_PKT_Count + LEN_Dram_addr);


// MSG_TYPE
localparam 		DRAM_DMA_DEPOSIT 					= 4,
				DRAM_DMA_REQ 						= 5,
				DRAM_DMA_RETURN 					= 6,
				CACHE_MISS_DRAM_REQ 				= 8,
				CACHE_MISS_DRAM_WRITE				= 9,
				CACHE_MISS_DRAM_RETURN 				= 10,
				DRAM_DMA_SHARED_REQ 				= 11,
				DRAM_DMA_SHARED_DEPOSIT 			= 12,
				DRAM_DMA_SHARED_RETURN 				= 13; 

// Memory Structure: processor ID starts with 0 
localparam 		TOTAL_PRIVATE_MEMORY 				= ((8/2)*1024*1024*1024)/8, // Memory Size 8 GB (/8 -> 64 bit Memory interface
				NO_TYPE_A_PROC 						= 10,
				TYPE_A_MEM_SIZE						= $clog2((128*1024*1024)/8), // 128 MB <- must be a power of 2
				NO_TYPE_B_PROC 						= 71,
				TYPE_B_MEM_SIZE						= $clog2((64*1024*1024)/8), // 64 MB <- must be a power of 2 // half of type A
				TOT_TYPE_B_MEM_OFFSET 				= (((128*1024*1024)/8)*NO_TYPE_A_PROC)/2;


wire 				[LEN_Dram_addr-1 : 0] 						addr_boundry_A0;
wire 				[LEN_Dram_addr-1 : 0] 						addr_boundry_A1;
wire 				[LEN_Dram_addr-1 : 0] 						addr_boundry_B0;
wire 				[LEN_Dram_addr-1 : 0] 						addr_boundry_B1;

reg address_test_pass;
reg reg_address_test_pass;



reg 				[STATE_BITS-1 : 0]							state = STATE_IDLE;
reg 				[$clog2(RHS_BURST_LEN+1): 0] 				burst_send_counter = 0; // maximum len = 8
reg 				[2*($clog2(RHS_BURST_LEN+1)): 0] 			max_burst_len_current = 0;
reg 				[LEN_TX_Count + LEN_PKT_Count : 0] 			max_burst_len_packet = 0;

reg 															rd_enbl_sc_inter = 0;
   
// wire 				[LEN_MSG_TYPE-1 :0]             			msg_type;
// wire 				[LEN_SRC_DST-1 : 0] 						pid_wire;
// wire                [LEN_SLOT_ID-1 : 0]                         slot_id;
// wire                [LEN_TX_COUNT-1 : 0]                        tx_count;
// //wire                [LEN_PKT_COUNT-1 : 0]                       pkt_count;
// wire 				[LEN_DRAM_ADDR-1 : 0] 						mem_addr_wire;
// wire                [LEN_SPARE_1-1 : 0 ]                        spare_1;
// wire                [LEN_SPARE_2-1 : 0 ]                        spare_2;

reg 				[2*($clog2(RHS_BURST_LEN+1)): 0] 			count_burst_current;

reg 				[3:0] 										flit_payload_size = 8;


wire 	[LEN_Valid-1:0] 			Valid;
wire 	[LEN_Tail-1:0] 				Tail;
wire 	[LEN_Dest-1:0] 				Dest;
wire 	[LEN_Spare1-1:0] 			Spare1;
wire 	[LEN_SRC_Dest-1:0] 			SRC_Dest;
wire 	[LEN_Spare2-1:0] 			Spare2;
wire 	[LEN_Msg_type-1:0] 			Msg_type; 
wire 	[LEN_Spare3-1:0] 			Spare3;
wire 	[LEN_SLOT_ID-1:0] 			SLOT_ID;
wire 	[LEN_Spare4-1:0] 			Spare4;
wire 	[LEN_SEQ_NUM-1:0] 			SEQ_NUM;
wire 	[LEN_TX_Count-1:0] 			TX_Count;
wire 	[LEN_Head-1:0] 				Head;
wire 	[LEN_PKT_Count-1:0] 		PKT_Count;
wire 	[LEN_Dram_addr-1:0] 		Dram_addr;
wire 	[LEN_Spare5-1:0] 			Spare5;
wire 	[LEN_DATA_RHS-1:0]  		data_flit;

wire 	[LEN_SRC_Dest-1 : 0] 			  pid_wire;
wire 	[LEN_Dram_addr-1 : 0] 		      mem_addr_wire;
 wire 	[LEN_Msg_type-1 :0]               msg_type;

assign {Valid, Tail, Dest, Spare1, SRC_Dest, Spare2, Msg_type, Spare3, SLOT_ID, Spare4, SEQ_NUM, TX_Count, Head, PKT_Count, Dram_addr, data_flit} = in_lhs_data;

assign pid_wire = SRC_Dest;
assign mem_addr_wire = Dram_addr;
assign msg_type = Msg_type;

assign out_ready_to_send_lhs = (((state == STATE_IDLE) & ((sc_in_ready_to_receive & ((Msg_type == CACHE_MISS_DRAM_REQ) | (Msg_type == CACHE_MISS_DRAM_WRITE))) | (dma_in_ready_to_receive & ((Msg_type == DRAM_DMA_DEPOSIT) | (Msg_type == DRAM_DMA_REQ) | (Msg_type == DRAM_DMA_SHARED_REQ) | (Msg_type == DRAM_DMA_SHARED_DEPOSIT))))) | (state == STATE_PAYLOAD_MRP) | (state == STATE_WRITE_DMA)) ? 1 : 0;

assign out_rd_enbl_sc = (rd_enbl_sc_inter & (~out_wr_enbl_sc)) ? 1: 0;

assign out_cd_avl_receive = out_ready_to_send_lhs;

assign out_pkt_size_dma =  max_burst_len_packet;


assign 	addr_boundry_A0 = pid_wire << TYPE_A_MEM_SIZE;
assign 	addr_boundry_A1 = (pid_wire+1) << TYPE_A_MEM_SIZE;

assign 	addr_boundry_B0 = pid_wire << TYPE_B_MEM_SIZE;
assign 	addr_boundry_B1 = ((pid_wire+1) << TYPE_B_MEM_SIZE) + TOT_TYPE_B_MEM_OFFSET;


always @(*) begin
	address_test_pass <= 0;
	if(mem_addr_wire > TOTAL_PRIVATE_MEMORY) begin
		address_test_pass <= 1;
	end else begin
		if(pid_wire > NO_TYPE_A_PROC) begin // TYPE B
			if((mem_addr_wire >= addr_boundry_B0) & (mem_addr_wire < addr_boundry_B1)) begin
				address_test_pass <= 1;
			end

		end else begin // TYPE A
			if((mem_addr_wire >= addr_boundry_A0) & (mem_addr_wire < addr_boundry_A1)) begin
				address_test_pass <= 1;
			end		

		end
	end

end




always @(posedge clk) begin
	if(~rst) begin
		state 			<= STATE_IDLE;

		out_wr_enbl_sc 				<= 1'b0;
		out_wr_enbl_data_sc 		<= 1'b0;
		rd_enbl_sc_inter	 		<= 1'b0;
		out_data_sc 				<= 0;
		out_data_dma 				<= 0;

		out_wr_enbl_dma 			<= 1'b0;
		out_addr_dma_en 			<= 1'b0;
		out_addr_dma_ctrl_en        <= 1'b0;
		out_data_dma_en 			<= 1'b0;

	end else begin

		out_wr_enbl_sc 				<= 1'b0;
		out_wr_enbl_data_sc 		<= 1'b0;
		rd_enbl_sc_inter	 		<= 1'b0;

		out_wr_enbl_dma 			<= 1'b0;
		out_addr_dma_en 			<= 1'b0;
		out_addr_dma_ctrl_en        <= 1'b0;
		out_data_dma_en 			<= 1'b0;


		case(state)
			STATE_IDLE: begin

				burst_send_counter 						<= 0;
				count_burst_current     				<= 0;

				if(in_available_lhs) begin

						case(msg_type)
							DRAM_DMA_DEPOSIT: begin
								if(dma_in_ready_to_receive) begin
									state 					<= STATE_IDLE;
									out_data_dma            <= 0;

//									out_wr_enbl_dma 			<= 1'b1;
//									out_addr_dma_en 			<= address_test_pass;
									out_addr_dma_ctrl_en        <= address_test_pass;
									reg_address_test_pass 		<= address_test_pass;

									out_addr_dma 				<= mem_addr_wire[LEN_ADDR-1: 0];
									out_processor_id_dma 		<= pid_wire;
									out_slot_id_dma 			<= SLOT_ID;
									max_burst_len_packet    	<= (TX_Count+1)*(PKT_Count+1);
									max_burst_len_current 		<= ((1) << 2);

									out_data_dma 				<= data_flit;
									out_wr_enbl_dma 			<= 1'b1;
									out_addr_dma_en 			<= address_test_pass;
									out_data_dma_en 	    	<= address_test_pass;
								end

							end
							DRAM_DMA_REQ: begin
								if(dma_in_ready_to_receive) begin
									state 						<= STATE_IDLE;

									out_wr_enbl_dma 			<= 1'b0;
									out_addr_dma_en 			<= address_test_pass;
									out_addr_dma_ctrl_en        <= address_test_pass;

									out_addr_dma 				<= mem_addr_wire[LEN_ADDR-1: 0];
									out_processor_id_dma 		<= pid_wire;
									out_slot_id_dma 			<= SLOT_ID;
									max_burst_len_packet    	<= (TX_Count+1)*(PKT_Count+1);
									max_burst_len_current 		<= ((1) << 2);
								end

							end
							CACHE_MISS_DRAM_REQ: begin

								if(sc_in_ready_to_receive) begin
									state 					<= STATE_IDLE;

									rd_enbl_sc_inter 		<= address_test_pass;
									out_wr_enbl_sc 			<= 0; // write to memory == 0 [if read -> let's forward necessary fields to scheduler asap]
									max_burst_len_current 	<= ((TX_Count+1) << 2);
									max_burst_len_packet    <= TX_Count;
									out_addr_sc				<= mem_addr_wire[LEN_ADDR-1: 0];
									out_processor_id_sc 	<= pid_wire;
									out_slot_id_sc          <= SLOT_ID;
								end

							end
							CACHE_MISS_DRAM_WRITE: begin

								if(sc_in_ready_to_receive) begin
									state 					<= STATE_IDLE;

									rd_enbl_sc_inter 		<= address_test_pass;
									out_wr_enbl_sc 			<= 1; // write to memory == 0 [if read -> let's forward necessary fields to scheduler asap]
									max_burst_len_current 	<= ((TX_Count+1) << 2);
									max_burst_len_packet    <= TX_Count;
									out_addr_sc				<= mem_addr_wire[LEN_ADDR-1: 0];
									out_processor_id_sc 	<= pid_wire;
									out_slot_id_sc          <= SLOT_ID;

									reg_address_test_pass 		<= address_test_pass;

									out_data_sc 				<= data_flit;
									out_wr_enbl_sc 				<= 1;
									out_wr_enbl_data_sc 		<= address_test_pass;
								end

							end
							DRAM_DMA_SHARED_REQ: begin
								if(dma_in_ready_to_receive) begin
									state 						<= STATE_IDLE;

									out_wr_enbl_dma 			<= 1'b0;
									out_addr_dma_en 			<= address_test_pass;
									out_addr_dma_ctrl_en        <= address_test_pass;

									out_addr_dma 				<= mem_addr_wire[LEN_ADDR-1: 0];
									out_processor_id_dma 		<= pid_wire;
									out_slot_id_dma 			<= SLOT_ID;
									max_burst_len_packet    	<= (TX_Count+1)*(PKT_Count+1);
									max_burst_len_current 		<= ((1) << 2);
								end
							end
							DRAM_DMA_SHARED_DEPOSIT: begin
								if(dma_in_ready_to_receive) begin
									state 					<= STATE_WRITE_DMA;
									out_data_dma            <= 0;

//									out_wr_enbl_dma 			<= 1'b1;
//									out_addr_dma_en 			<= address_test_pass;
									out_addr_dma_ctrl_en        <= address_test_pass;
									reg_address_test_pass 		<= address_test_pass;

									out_addr_dma 				<= mem_addr_wire[LEN_ADDR-1: 0];
									out_processor_id_dma 		<= pid_wire;
									out_slot_id_dma 			<= SLOT_ID;
									max_burst_len_packet    	<= (TX_Count+1)*(PKT_Count+1);
									max_burst_len_current 		<= ((1) << 2);

									out_data_dma 				<= data_flit;
									out_wr_enbl_dma 			<= 1'b1;
									out_addr_dma_en 			<= address_test_pass;
									out_data_dma_en 	    	<= address_test_pass;
								end
							end
							default:
								state 					<= STATE_IDLE;
						endcase
				end
			end
			STATE_PAYLOAD_MRP: begin
				if(burst_send_counter == (max_burst_len_current-1)) begin
			    	state                       <= STATE_IDLE;
			    	out_wr_enbl_data_sc 		<= reg_address_test_pass;
				end
            	if(in_available_lhs) begin
			    	burst_send_counter 			<= burst_send_counter + 1;
			    	out_data_sc 				<= (out_data_sc << LEN_DATA_LHS) + in_lhs_data;
			    	
				    if( (max_burst_len_packet > 0)) begin
	   				    if(count_burst_current < max_burst_len_packet) begin
	       				    rd_enbl_sc_inter 			<= reg_address_test_pass;
	       				    out_wr_enbl_sc 				<= 1;
	       				    out_addr_sc              	<= out_addr_sc + 7'd8;
	       				    count_burst_current      	<= count_burst_current + 1'b1;
	       				    out_wr_enbl_data_sc 		<= reg_address_test_pass;
	   				    end
				    end
				end
			end
			STATE_WRITE_DMA: begin 
				if (dma_in_ready_to_receive) begin
					if (in_available_lhs) begin
					    out_data_dma 				<= (out_data_dma << LEN_DATA_LHS) + in_lhs_data;
						if(burst_send_counter == (max_burst_len_current-1))  begin
							out_data_dma_en 	    <= reg_address_test_pass;
							state 					<= STATE_IDLE;
							out_wr_enbl_dma 			<= 1'b1;
							out_addr_dma_en 			<= reg_address_test_pass;
						end
						else begin
							burst_send_counter <= burst_send_counter +1;
						end
						
					end
				end
			end
			// STATE_READ_DMA: begin

			// 	if (dma_in_ready_to_receive) begin
			// 		if(in_available_lhs) begin
			// 			burst_send_counter 			<= burst_send_counter + 1;

			// 			out_addr_dma 				<= mem_addr_wire[LEN_ADDR-1: 0];

			// 			if(burst_send_counter == (max_burst_len_packet)) begin
			// 				state 					<= STATE_IDLE;
			// 				out_dma_start 			<= 1'b1;
			// 			end else begin
			// 				out_wr_enbl_dma 			<= 1'b1;
			// 				out_addr_dma_en 			<= 1'b1;
			// 			end
			// 		end
			// 	end

			// end
			
			default:
				state 			<= STATE_IDLE;
		endcase
	end
end

endmodule