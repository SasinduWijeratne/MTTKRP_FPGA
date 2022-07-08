`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: pgroup @ usc
// Engineer: Sasindu Wijeratne 
// 
// Create Date: 08/05/2020 04:38:03 PM
// Design Name: 
// Module Name: wrapper_top2
// Project Name: 
// Target Devices: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module wrapper_top_cache #(
parameter 	LEN_ADDR 			=	32,
parameter 	LEN_PROCESSOR_NO 	= 	 7,
parameter 	RHS_BURST_LEN 		= 	 4,
parameter 	LEN_FLIT_DATA_LHS 	= 	608,	
parameter 	LEN_MEM_ADDR 		= 	35,
parameter   LEN_SLOT_ID         =    7,
parameter   PACKT_LEN           =   13,
parameter   NUM_DMA             =    4,
parameter 	LEN_MEM_DATA 		= 	512
	)
	(


input 	wire 										clk,
input   wire                                        mem_clk,
input 	wire 										rst,

// input from LHS processor
input 	wire 										in_LHS_ready_send_top,
input 	wire 										in_LHS_ready_receive_top,
input 	wire 	[LEN_FLIT_DATA_LHS-1: 0] 			in_LHS_FLIT_data_top,


// input from RHS memory interface
input 	wire	[LEN_MEM_DATA-1: 0]					in_RHS_data_top,
input 	wire 										in_RHS_in_data_ready_top,
input 	wire 										in_RHS_avl_top,

// output to LHS processor
output 	wire 										out_cd_ready_to_receive_LHS_top,
output 	wire 										out_fu_ready_to_send_LHS_top,
output 	wire 	[LEN_FLIT_DATA_LHS-1: 0] 			out_LHS_FLIT_data_top,
output  wire                                        out_cd_avl_receive, 

// output to RHS memory interface
output 	wire	[LEN_ADDR-1: 0]						out_RHS_addr_top,
output 	wire	[LEN_MEM_DATA-1: 0]					out_RHS_data_top,
output 	wire 										out_RHS_wrt_en_top,
output 	wire 										out_ready_to_receive_top,
output 	wire 										out_RHS_avl_top,
output 	wire 										out_burst_done,

// stat collection
output 	wire 	[1:0]                               stat_occupancy

    );


wire 	[LEN_ADDR-1: 0] 					CD_in_addr_sc;
wire 	[LEN_PROCESSOR_NO-1: 0] 			CD_in_processor_id_sc;
wire    [LEN_SLOT_ID-1 : 0]                 CD_in_slot_id_sc;
wire 	[LEN_MEM_DATA-1: 0] 			    CD_in_data_sc;
wire 					 					CD_in_rd_enbl_sc; // LHS enable
wire 					 					CD_in_wr_enbl_sc; // LHS enable
wire 					 					CD_in_wr_enbl_data_sc; // LHS enable
wire 										sc_ready_to_receive_CD;
wire 	[LEN_PROCESSOR_NO-1: 0] 			sc_in_processor_id_fu;
wire    [LEN_SLOT_ID-1: 0]                  sc_in_slot_id_fu;
wire 	[LEN_MEM_DATA-1: 0] 			    sc_in_data_fu;
wire 	[LEN_ADDR-1: 0] 					sc_in_addr_fu;
wire 										sc_in_data_ready_for_fu;
wire 										fu_ready_to_receive_sc;
wire 										fu_ready_to_receive_data_sc;

wire	[LEN_ADDR-1: 0]						out_RHS_addr_sch;
wire	[LEN_MEM_DATA-1: 0]			        out_RHS_data_sch;
wire 										out_RHS_wrt_en_sch;
wire 										out_ready_to_receive_sch;
wire 										out_RHS_avl_sch;
wire 										out_burst_done_sch;
wire	[LEN_MEM_DATA-1: 0]			        in_RHS_data_sch;
wire 										in_RHS_in_data_ready_sch;
wire 										in_RHS_avl_sch;
wire 									    out_RHS_wrt_en_top0;

wire    [NUM_DMA-1 : 0]                     dma_in_id_sch;
wire    [NUM_DMA-1 : 0]                     dma_out_id_sch;


//DMA Output to Command Decoder
wire 										ready_to_receive_CD_dma;

// DMA input from Command Decoder
wire 	[LEN_ADDR-1: 0] 					in_CD_addr_dma;
wire 	[LEN_PROCESSOR_NO-1: 0] 			in_CD_processor_id_dma;
wire    [LEN_SLOT_ID-1 : 0]                 CD_in_slot_id_dma;
wire    [PACKT_LEN-1 : 0]                   CD_in_pkt_size_dma;
wire 	[LEN_MEM_DATA-1: 0] 			   in_CD_data_dma;
wire 										in_CD_wrt_dma;
wire 										in_CD_addr_en_dma;
wire                                        in_CD_addr_ctrl_en;
wire 										in_CD_data_en_dma;

//DMA Input from forwarding unit
wire 										FU_ready_to_receive_data_dma;

//DMA Output to forwarding unit
wire 	[LEN_PROCESSOR_NO-1: 0] 			FU_out_processor_id_dma;
wire 	[LEN_MEM_DATA-1: 0] 			    FU_out_data_dma;
wire 	[LEN_ADDR-1: 0] 					FU_out_addr_dma;
wire 										FU_out_data_ready_for_fu_dma;
wire    [PACKT_LEN-1 : 0]                   FU_out_tx_count_dma;
wire 	[LEN_SLOT_ID-1: 0] 			        FU_out_slot_id_dma;

//DMA Input from memory interface
wire 	[LEN_MEM_DATA-1: 0] 				mem_in_data_dma;
wire 					 					mem_in_ready_to_receive_dma;
wire    [NUM_DMA-1 : 0]                     mem_in_id_dma;
wire 										mem_in_data_ready_dma;

//DMA Output to memory interface
wire 	[LEN_ADDR-1: 0] 					mem_out_addr_dma;
wire 	[LEN_MEM_DATA-1: 0] 				mem_out_data_dma;
wire 										out_wrt_enbl_mem_dma;
wire 										out_receive_enbl_mem_dma;
wire 										out_available_mem_dma;
wire    [NUM_DMA-1 : 0]                     dma_mem_out_id;
wire 										out_burst_done_dma;


//CD Input from dma
wire 										dma_in_ready_to_receive;

// CD Output to dma
wire 	[LEN_ADDR-1: 0] 					out_addr_dma;
wire	[LEN_PROCESSOR_NO-1: 0] 			out_processor_id_dma;
wire    [LEN_SLOT_ID-1 : 0]                 out_slot_id_dma;
wire    [PACKT_LEN-1 : 0]                   out_pkt_size_dma;
wire 	[LEN_MEM_DATA-1: 0] 			out_data_dma;
wire 					 					out_wr_enbl_dma;
wire					 					out_addr_dma_en;
wire                                        out_addr_dma_ctrl_en;
wire 					 					out_data_dma_en;

// FU Input from DMA
wire 	[LEN_PROCESSOR_NO-1: 0] 			dma_in_processor_id_fu;
wire 	[LEN_MEM_DATA-1: 0] 			    dma_in_data_fu;
wire 	[LEN_ADDR-1: 0] 					dma_in_addr_fu;
wire 										dma_in_data_ready_for_fu;
wire    [PACKT_LEN-1 : 0]                   dma_in_tx_count_fu;
wire 	[LEN_SLOT_ID-1: 0] 			        dma_in_slot_id_fu;

//FU Output to DMA
wire 										dma_ready_to_receive_data_fu;

// SCH Input from DMA
wire 	[LEN_ADDR-1: 0] 					dma_in_addr_sch;
wire 	[LEN_MEM_DATA-1: 0] 				dma_in_data_sch;
wire 										dma_in_wrt_enbl_mem_sch;
wire 										dma_in_receive_enbl_mem_sch;
wire 										dma_in_available_mem_sch;
wire 										dma_in_burst_done_sch;

//SCH Output to DMA
wire		[LEN_MEM_DATA-1: 0] 				dma_out_data_sch;
wire						 					dma_in_ready_to_receive_sch;
wire											dma_out_data_ready_sch;


// Command Decoder and DMA
assign 	in_CD_addr_dma 				= out_addr_dma;
assign 	in_CD_processor_id_dma 		= out_processor_id_dma;
assign  CD_in_slot_id_dma 			= out_slot_id_dma;
assign  CD_in_pkt_size_dma 			= out_pkt_size_dma;
assign 	in_CD_data_dma 				= out_data_dma;
assign 	in_CD_wrt_dma 				= out_wr_enbl_dma;
assign 	in_CD_addr_en_dma 			= out_addr_dma_en;
assign  in_CD_data_en_dma 			= out_data_dma_en;
assign  in_CD_addr_ctrl_en          = out_addr_dma_ctrl_en;

//DMA and forwarding unit
assign	FU_ready_to_receive_data_dma = dma_ready_to_receive_data_fu;
assign 	dma_in_processor_id_fu 		= FU_out_processor_id_dma;
assign 	dma_in_data_fu 				= FU_out_data_dma;
assign 	dma_in_addr_fu 				= FU_out_addr_dma;
assign 	dma_in_data_ready_for_fu 	= FU_out_data_ready_for_fu_dma;
assign  dma_in_tx_count_fu 			= FU_out_tx_count_dma;
assign 	dma_in_slot_id_fu 			= FU_out_slot_id_dma;

//DMA and Scheduler
assign	mem_in_data_dma 					= dma_out_data_sch;
assign	mem_in_ready_to_receive_dma 		= dma_in_ready_to_receive_sch;
assign	mem_in_data_ready_dma 				= dma_out_data_ready_sch;
assign	dma_in_addr_sch 					= mem_out_addr_dma;
assign	dma_in_data_sch 					= mem_out_data_dma;
assign	dma_in_wrt_enbl_mem_sch 			= out_wrt_enbl_mem_dma;
assign	dma_in_receive_enbl_mem_sch 		= out_receive_enbl_mem_dma;
assign	dma_in_available_mem_sch 			= out_available_mem_dma;
assign	dma_in_burst_done_sch 				= out_burst_done_dma;
assign mem_in_id_dma                        = dma_out_id_sch;
assign dma_in_ready_to_receive 	            = ready_to_receive_CD_dma;
assign out_RHS_wrt_en_top 		            = out_RHS_wrt_en_top0 & out_RHS_avl_top;
assign dma_in_id_sch                        = dma_mem_out_id;

	command_decoder_dma
	/*#(
			.LEN_ADDR(LEN_ADDR),
			.LEN_PROCESSOR_NO(LEN_PROCESSOR_NO),
			.RHS_BURST_LEN(RHS_BURST_LEN),
			.LEN_DATA_LHS(LEN_FLIT_DATA_LHS)
		) */
		inst_command_decoder (
			.clk                    (clk),
			.rst                    (rst),

			//Input from scheduler
			.sc_in_ready_to_receive (sc_ready_to_receive_CD),

			//Input from dma
			.dma_in_ready_to_receive(dma_in_ready_to_receive),

			// Input from the LHS
			.in_lhs_data            (in_LHS_FLIT_data_top),
			.in_available_lhs       (in_LHS_ready_send_top),

			//Output to scheduler
			.out_addr_sc            (CD_in_addr_sc),
			.out_processor_id_sc    (CD_in_processor_id_sc),
			.out_slot_id_sc         (CD_in_slot_id_sc),
			.out_data_sc            (CD_in_data_sc),
			.out_rd_enbl_sc         (CD_in_rd_enbl_sc),
			.out_wr_enbl_sc         (CD_in_wr_enbl_sc),
			.out_wr_enbl_data_sc    (CD_in_wr_enbl_data_sc),

			//Output to dma
			.out_addr_dma(out_addr_dma),
 	 		.out_processor_id_dma(out_processor_id_dma),
            .out_slot_id_dma(out_slot_id_dma),
            .out_pkt_size_dma(out_pkt_size_dma),
 	 		.out_data_dma(out_data_dma),
 	 		.out_wr_enbl_dma(out_wr_enbl_dma),
 	 		.out_addr_dma_ctrl_en(out_addr_dma_ctrl_en),
 	 		.out_addr_dma_en(out_addr_dma_en),
 	 		.out_data_dma_en(out_data_dma_en),

			// Output to the LHS
			.out_ready_to_send_lhs  (out_cd_ready_to_receive_LHS_top),
			.out_cd_avl_receive     (out_cd_avl_receive)
		);

	scheduler_wrapper_cache
	/*#(
			.LEN_ADDR(LEN_ADDR),
			.LEN_PROCESSOR_NO(LEN_PROCESSOR_NO),
			.RHS_BURST_LEN(RHS_BURST_LEN),
			.LEN_DATA_RHS(LEN_FLIT_DATA_LHS),
			.LEN_DATA_LHS(LEN_FLIT_DATA_LHS)
		)*/
		 inst_scheduler_wrapper_cache_2 (
			.clk                      (clk),
			.rst                      (rst),

			//Input from Command Decoder
			.CD_in_addr               (CD_in_addr_sc),
			.CD_in_processor_id       (CD_in_processor_id_sc),
			.CD_in_data               (CD_in_data_sc),
			.CD_in_rd_enbl            (CD_in_rd_enbl_sc),
			.CD_in_wr_enbl            (CD_in_wr_enbl_sc),
			.CD_in_wr_enbl_data       (CD_in_wr_enbl_data_sc),
			.CD_in_slot_id            (CD_in_slot_id_sc),

			//Input from forwarding unit
			.FU_ready_to_receive      (fu_ready_to_receive_sc),
			.FU_ready_to_receive_data (fu_ready_to_receive_data_sc),

			//Input from memory interface
			.mem_in_data              (in_RHS_data_sch),
			.mem_in_ready_to_receive  (in_RHS_avl_sch),
			.mem_in_data_ready        (in_RHS_in_data_ready_sch),

			// Input from DMA
			.dma_in_addr(dma_in_addr_sch),
			.dma_in_data(dma_in_data_sch),
			.dma_in_wrt_enbl_mem(dma_in_wrt_enbl_mem_sch),
			.dma_in_receive_enbl_mem(dma_in_receive_enbl_mem_sch),
			.dma_in_available_mem(dma_in_available_mem_sch),
			.dma_in_id(dma_in_id_sch),
			.dma_in_burst_done(dma_in_burst_done_sch),			

			//Output to Command Decoder
			.ready_to_receive_CD      (sc_ready_to_receive_CD),

			//Output to forwarding unit
			.FU_out_processor_id      (sc_in_processor_id_fu),
			.FU_out_data              (sc_in_data_fu),
			.FU_out_addr              (sc_in_addr_fu),
			.FU_out_data_ready_for_fu (sc_in_data_ready_for_fu),
			.FU_out_slot_id           (sc_in_slot_id_fu),

			//Output to DMA
			.dma_out_data(dma_out_data_sch),
			.dma_out_id(dma_out_id_sch),
			.dma_in_ready_to_receive(dma_in_ready_to_receive_sch),
			.dma_out_data_ready(dma_out_data_ready_sch),			

			//Output to memory interface
			.mem_out_addr             (out_RHS_addr_sch),
			.mem_out_data             (out_RHS_data_sch),
			.out_wrt_enbl_mem         (out_RHS_wrt_en_sch),
			.out_receive_enbl_mem     (out_ready_to_receive_sch),
			.out_available_mem        (out_RHS_avl_sch),
			.out_burst_done 		  (out_burst_done_sch),
			
			// stat
			.stat_occupancy(stat_occupancy)
		);

	forwarding_unit_wrapper_dma 
	/*#(
			.LEN_ADDR(LEN_ADDR),
			.LEN_PROCESSOR_NO(LEN_PROCESSOR_NO),
			.RHS_BURST_LEN(RHS_BURST_LEN),
			.LEN_DATA_LHS(LEN_FLIT_DATA_LHS)
		) */
		inst_forwarding_unit_wrapper_dma (
			.clk                      (clk),
			.rst                      (rst),
			// Input from the scheduler
			.sc_in_processor_id       (sc_in_processor_id_fu),
			.sc_in_slot_id            (sc_in_slot_id_fu),
			.sc_in_data               (sc_in_data_fu),
			.sc_in_addr               (sc_in_addr_fu),
			.sc_in_data_ready_for_fu  (sc_in_data_ready_for_fu),
			.sc_in_ready_to_send       (),

			//Input from DMA
			.dma_in_processor_id(dma_in_processor_id_fu),
			.dma_in_data(dma_in_data_fu),
			.dma_in_addr(dma_in_addr_fu),
			.dma_in_data_ready_for_fu(dma_in_data_ready_for_fu),
			.dma_in_tx_count(dma_in_tx_count_fu),
			.dma_in_slot_id(dma_in_slot_id_fu),

			.LHS_in_ready_to_receive  (in_LHS_ready_receive_top),
			.ready_to_receive_sc      (fu_ready_to_receive_sc),
			.ready_to_receive_data_sc (fu_ready_to_receive_data_sc),

			//Output to DMA
			.dma_ready_to_receive_data(dma_ready_to_receive_data_fu),

			// Output to the LHS
			.out_lhs_data             (out_LHS_FLIT_data_top),
			.out_available_lhs        (out_fu_ready_to_send_LHS_top)

		);
		
 issue_to_DDR_DMA 
 /*#(
 	.LEN_ADDR(LEN_ADDR),
 	.LEN_DATA_LHS(LEN_FLIT_DATA_LHS),
 	.LEN_DATA_RHS(LEN_MEM_DATA)
	) */
	inst_issue_to_DDR (
	.clk(clk),
    .rst(rst),
    .mem_clk(mem_clk),
    //input from scheduler
	.in_sch_mem_out_addr(out_RHS_addr_sch),
	.in_sch_mem_out_data(out_RHS_data_sch),
    .in_sch_out_wrt_enbl_mem(out_RHS_wrt_en_sch),
    .in_sch_out_receive_enbl_mem(out_ready_to_receive_sch),
    .in_sch_out_available_mem(out_RHS_avl_sch),
    .in_sch_out_burst_done(out_burst_done_sch),
    
    //Input from memory interface
	.mem_in_data(in_RHS_data_top),
	.mem_in_ready_to_receive(in_RHS_avl_top),
	.mem_in_data_ready(in_RHS_in_data_ready_top),
    //output to scheduler
    .out_sch_mem_in_data(in_RHS_data_sch),
    .out_sch_mem_in_ready_to_receive(in_RHS_avl_sch), // RHS is accepting data
    .out_sch_mem_in_data_ready(in_RHS_in_data_ready_sch), // RHS data available
    
    
    //Output to memory interface,
    .mem_out_addr             (out_RHS_addr_top),
	.mem_out_data             (out_RHS_data_top),
	.out_wrt_enbl_mem         (out_RHS_wrt_en_top0),
	.out_receive_enbl_mem     (out_ready_to_receive_top),
	.out_available_mem        (out_RHS_avl_top),
	.out_burst_done 		  (out_burst_done)
    );
    
DMA_top inst_DMA_top (

	.clk(clk),
	.rst(rst),

//input from Command Decoder
	.in_CD_addr(in_CD_addr_dma),
	.in_CD_processor_id(in_CD_processor_id_dma),
    .CD_in_slot_id(CD_in_slot_id_dma),
    .CD_in_pkt_size(CD_in_pkt_size_dma),
	.in_CD_data(in_CD_data_dma),
	.in_CD_wrt(in_CD_wrt_dma),
	.in_CD_addr_ctrl_en(in_CD_addr_ctrl_en),
	.in_CD_addr_en(in_CD_addr_en_dma),
	.in_CD_data_en(in_CD_data_en_dma),

//Input from forwarding unit
	.FU_ready_to_receive_data(FU_ready_to_receive_data_dma),

//Input from memory interface
	.mem_in_data(mem_in_data_dma),
	.mem_in_id(mem_in_id_dma),
	.mem_in_ready_to_receive(mem_in_ready_to_receive_dma),
	.mem_in_data_ready(mem_in_data_ready_dma),

//Output to memory interface
	.mem_out_addr(mem_out_addr_dma),
	.mem_out_data(mem_out_data_dma),
	.out_wrt_enbl_mem(out_wrt_enbl_mem_dma),
	.out_receive_enbl_mem(out_receive_enbl_mem_dma),
	.out_available_mem(out_available_mem_dma),
	.mem_out_id(dma_mem_out_id),
	.out_burst_done(out_burst_done_dma),

//Output to forwarding unit
	.FU_out_processor_id(FU_out_processor_id_dma),
	.FU_out_data(FU_out_data_dma),
	.FU_out_addr(FU_out_addr_dma),
	.FU_out_data_ready_for_fu(FU_out_data_ready_for_fu_dma),
    .FU_out_tx_count(FU_out_tx_count_dma),
    .FU_out_slot_id(FU_out_slot_id_dma),

//Output to Command Decoder
	.ready_to_receive_CD(ready_to_receive_CD_dma)



);

endmodule