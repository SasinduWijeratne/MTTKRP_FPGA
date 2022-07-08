`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/29/2021 11:15:13 PM
// Design Name: 
// Module Name: mttkrp_wrapper_top_cache
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


module mttkrp_wrapper_top_cache #(
parameter 	LEN_MEM_DATA 		= 	512,
parameter 	LEN_ADDR 			=	32,

parameter TENSOR_WIDTH              = 128,
parameter TENSOR_DIMENSIONS         = 3,
parameter FACTOR_MATRIX_WIDTH       = 32,
parameter RANK_FACTOR_MATRIX        = 16,
parameter NUM_INTERNAL_MEM_TENSOR   = 1024,
parameter TENSOR_DATA_WIDTH         = 32,
parameter MODE_TENSOR_BLOCK_WIDTH   = 16,
parameter MODE_TENSOR_ADDR_WIDTH    = 16,
parameter NUM_OF_SHARDS             = 1024,
parameter DMA_DATA_WIDTH            = 512,
parameter NUM_COMPUTE_UNITS         = 4

)(

input 	wire 										clk,
input   wire                                        mem_clk,
input 	wire 										rst,

// input from RHS memory interface
input 	wire	[LEN_MEM_DATA-1: 0]					in_RHS_data_top,
input 	wire 										in_RHS_in_data_ready_top,
input 	wire 										in_RHS_avl_top,

// output to RHS memory interface
output 	wire	[LEN_ADDR-1: 0]						out_RHS_addr_top,
output 	wire	[LEN_MEM_DATA-1: 0]					out_RHS_data_top,
output 	wire 										out_RHS_wrt_en_top,
output 	wire 										out_ready_to_receive_top,
output 	wire 										out_RHS_avl_top,
output 	wire 										out_burst_done
    );


localparam      NUM_DMA             =    3;

localparam   NUM_CACHES             =    TENSOR_DIMENSIONS-1;
localparam 	LEN_PROCESSOR_NO 	    = 	 7;
localparam 	RHS_BURST_LEN 		    = 	 8;
localparam 	LEN_DATA_RHS 		    = 	 512;
localparam   LEN_SLOT_ID            =    LEN_PROCESSOR_NO;
localparam 	LEN_DATA_LHS 		    = 	 512;

localparam  PACKT_LEN               =    13;

// DMA: Tensor, partition wr, Reorder

//input from Command Decoder
wire 	[NUM_DMA-1 : 0][LEN_ADDR-1: 0] 					    in_CD_addr_dma;
wire 	[NUM_DMA-1 : 0][LEN_PROCESSOR_NO-1: 0] 			    in_CD_processor_id_dma;
wire    [NUM_DMA-1 : 0][LEN_SLOT_ID-1 : 0]                  CD_in_slot_id_dma;
wire    [NUM_DMA-1 : 0][PACKT_LEN-1 : 0]                    CD_in_pkt_size_dma;
wire 	[NUM_DMA-1 : 0][LEN_DATA_LHS-1: 0] 				    in_CD_data_dma;
wire 	[NUM_DMA-1 : 0]									    in_CD_wrt_dma;
wire 	[NUM_DMA-1 : 0]						                in_CD_addr_en_dma;
wire 	[NUM_DMA-1 : 0]									    in_CD_data_en_dma;

//Output to Command Decoder
wire [NUM_DMA-1 : 0]							    ready_to_receive_CD;


//Input from forwarding unit
wire [NUM_DMA-1:0]										    FU_ready_to_receive_data_FU;

//Output to forwarding unit
wire 	[NUM_DMA-1:0][LEN_PROCESSOR_NO-1: 0] 			    FU_out_processor_id_FU;
wire 	[NUM_DMA-1:0][LEN_DATA_LHS-1: 0] 				    FU_out_data_FU;
wire 	[NUM_DMA-1:0][LEN_ADDR-1: 0] 					    FU_out_addr_FU;
wire 	[NUM_DMA-1:0]									    FU_out_data_ready_for_fu_FU;
wire     [NUM_DMA-1:0][PACKT_LEN-1 : 0]                      FU_out_tx_count_FU;
wire 	[NUM_DMA-1:0][LEN_SLOT_ID-1: 0] 			        FU_out_slot_id_FU;

/*     MTTKRP Compute Unit     */
wire                                                                                        begining_of_shard_pe;
wire                                                                                        end_of_shard_pe;
wire                                                                                        factor_data_ack_pe;
wire                                                                                        adder_tree_ready_to_receive_pe;
wire                                                                                        tensor_element_en_pe;
wire [TENSOR_WIDTH-1 : 0]                                                                   tensor_element_pe; // | BL_X | BL_Y | BL_Z | X | Y | Z | VAL |

wire [TENSOR_DIMENSIONS-2 : 0]                                                              input_factor_matrices_en_pe;
wire [TENSOR_DIMENSIONS-2 : 0] [RANK_FACTOR_MATRIX-1 : 0] [FACTOR_MATRIX_WIDTH-1 : 0]       input_factor_matrices_pe;
wire [LEN_PROCESSOR_NO-1 : 0]                                                               input_compute_id_factor_matrices_pe;

wire [TENSOR_DIMENSIONS-2 : 0]                                                              output_factor_matrices_addr_en_pe;
wire [TENSOR_DIMENSIONS-2 : 0] [MODE_TENSOR_ADDR_WIDTH-1 : 0]                               output_factor_matrices_addr_pe;
wire [LEN_PROCESSOR_NO-1 : 0]                                                               output_compute_id_factor_matrices_pe;

wire                                                                                        op_done_ack_pe;
wire                                                                                        output_to_adder_tree_en_pe;
wire [RANK_FACTOR_MATRIX-1 : 0] [FACTOR_MATRIX_WIDTH-1 : 0]                                 output_to_adder_tree_pe;
wire                                                                                       reordered_tensor_element_en_pe;
wire [TENSOR_WIDTH-1 : 0]                                                                  reordered_tensor_element_pe; // | BL_X | BL_Y | BL_Z | X | Y | Z | VAL |

//Command Decoder
wire 	[NUM_CACHES-1 : 0][LEN_ADDR-1: 0] 					    CD_in_addr;
wire 	[NUM_CACHES-1 : 0][LEN_PROCESSOR_NO-1: 0] 			    CD_in_processor_id;
wire 	[NUM_CACHES-1 : 0][LEN_DATA_LHS-1: 0] 				    CD_in_data;
wire 	[NUM_CACHES-1 : 0]				 					    CD_in_rd_enbl; // LHS enable
wire 	[NUM_CACHES-1 : 0]				 					    CD_in_wr_enbl; // LHS enable
wire 	[NUM_CACHES-1 : 0]				 					    CD_in_wr_enbl_data; // LHS enable
wire    [NUM_CACHES-1 : 0][LEN_SLOT_ID-1 : 0]                   CD_in_slot_id;

wire 	[NUM_CACHES-1 : 0][LEN_PROCESSOR_NO-1: 0] 			    FU_out_processor_id;
wire 	[NUM_CACHES-1 : 0][LEN_DATA_LHS-1: 0] 				    FU_out_data;
wire 	[NUM_CACHES-1 : 0][LEN_ADDR-1: 0] 					    FU_out_addr;
wire 	[NUM_CACHES-1 : 0]									    FU_out_data_ready_for_fu;
wire 	[NUM_CACHES-1 : 0][LEN_SLOT_ID-1: 0] 			        FU_out_slot_id;



/* scheduler*/
wire	[LEN_ADDR-1: 0]						out_RHS_addr_sch;
wire	[LEN_MEM_DATA-1: 0]			        out_RHS_data_sch;
wire 										out_RHS_wrt_en_sch;
wire 										out_ready_to_receive_sch;
wire 										out_RHS_avl_sch;
wire 										out_burst_done_sch;
wire	[LEN_MEM_DATA-1: 0]			        in_RHS_data_sch;
wire 										in_RHS_in_data_ready_sch;
wire 										in_RHS_avl_sch;

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

// SCH Input from DMA
wire 	[LEN_ADDR-1: 0] 					dma_in_addr_sch;
wire 	[LEN_MEM_DATA-1: 0] 				dma_in_data_sch;
wire 										dma_in_wrt_enbl_mem_sch;
wire 										dma_in_receive_enbl_mem_sch;
wire 										dma_in_available_mem_sch;
wire 										dma_in_burst_done_sch;
wire    [NUM_DMA-1 : 0]                     dma_in_id_sch;

//SCH Output to DMA
wire	[LEN_MEM_DATA-1: 0] 				    dma_out_data_sch;
wire						 					dma_in_ready_to_receive_sch;
wire											dma_out_data_ready_sch;
wire    [NUM_DMA-1 : 0]                         dma_out_id_sch;

wire 										ready_to_receive_CD_dma;


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

// scheduler and PE
assign 	CD_in_addr          = output_factor_matrices_addr_pe;
assign 	CD_in_processor_id  = output_compute_id_factor_matrices_pe;
assign 	CD_in_data          = 0;
assign	CD_in_rd_enbl       = output_factor_matrices_addr_en_pe; // LHS enable
assign	CD_in_wr_enbl       = 0; // LHS enable
assign	CD_in_wr_enbl_data  = 0; // LHS enable
assign  CD_in_slot_id       = output_compute_id_factor_matrices_pe;

assign  input_factor_matrices_en_pe         = FU_out_data_ready_for_fu;
assign  input_factor_matrices_pe            = FU_out_data;
assign  input_compute_id_factor_matrices_pe = FU_out_slot_id;

// DMA: Tensor, partition wr, Reorder
assign in_CD_addr_dma[0] = 0;
assign in_CD_processor_id_dma[0] = 0;
assign CD_in_slot_id_dma[0] = 0;
assign CD_in_pkt_size_dma[0] = 1024;
assign in_CD_data_dma[0] = 0;
assign in_CD_wrt_dma[0] = 0;
assign in_CD_addr_en_dma[0] = 1;
assign in_CD_data_en_dma[0] = 0;

assign in_CD_addr_dma[1] = 0;
assign in_CD_processor_id_dma[1] = 0;
assign CD_in_slot_id_dma[1] = 0;
assign CD_in_pkt_size_dma[1] = 1024;
assign in_CD_wrt_dma[1] = 1;
assign in_CD_addr_en_dma[1] = 1;
// assign in_CD_data_en_dma[1] = 1;

assign in_CD_addr_dma[2] = 0;
assign in_CD_processor_id_dma[2] =0;
assign CD_in_slot_id_dma[2] = 0;
assign CD_in_pkt_size_dma[2] = 1024;
assign in_CD_data_dma[2] = output_to_adder_tree_pe;
assign in_CD_wrt_dma[2] = output_to_adder_tree_en_pe;
assign in_CD_addr_en_dma[2] = output_to_adder_tree_en_pe;
assign in_CD_data_en_dma[2]= output_to_adder_tree_en_pe;

assign begining_of_shard_pe = 1'b0; 
assign FU_ready_to_receive_data_FU[0] = end_of_shard_pe;
assign FU_ready_to_receive_data_FU[1] = adder_tree_ready_to_receive_pe;

// 512 --> 128
fifo_memory_to_tensor inst_fifo_memory_to_tensor (
    .clk(clk),
    .din(FU_out_data_FU[0]),
    .wr_en(FU_out_data_ready_for_fu_FU[0]),
    .rd_en(tensor_element_en_pe),
    .dout(tensor_element_pe),
    .full(~FU_ready_to_receive_data_FU[0]),
    .empty()
);

// 128 -> 512
fifo_tensor_to_memory inst_fifo_tensor_to_memory (
    .clk(clk),
    .din(reordered_tensor_element_pe),
    .wr_en(reordered_tensor_element_en_pe),
    .rd_en(ready_to_receive_CD[1]),
    .dout(in_CD_data_dma[1]),
    .full(),
    .empty(~in_CD_data_en_dma[1])
);

mttkrp_scheduler_wrapper_cache 
#(
    .LEN_ADDR         (LEN_ADDR         ),
    .NUM_CACHES       (NUM_CACHES       ),
    .LEN_PROCESSOR_NO (LEN_PROCESSOR_NO ),
    .RHS_BURST_LEN    (RHS_BURST_LEN    ),
    .LEN_DATA_RHS     (LEN_DATA_RHS     ),
    .LEN_SLOT_ID      (LEN_SLOT_ID      ),
    .NUM_DMA          (NUM_DMA          ),
    .LEN_DATA_LHS     (LEN_DATA_LHS     )
)
u_mttkrp_scheduler_wrapper_cache(
    .clk                      (clk                      ),
    .rst                      (rst                      ),

    .CD_in_addr               (CD_in_addr               ),
    .CD_in_processor_id       (CD_in_processor_id       ),
    .CD_in_data               (CD_in_data               ),
    .CD_in_rd_enbl            (CD_in_rd_enbl            ),
    .CD_in_wr_enbl            (CD_in_wr_enbl            ),
    .CD_in_wr_enbl_data       (CD_in_wr_enbl_data       ),
    .CD_in_slot_id            (CD_in_slot_id            ),

    .FU_ready_to_receive      (FU_ready_to_receive      ),
    .FU_ready_to_receive_data (FU_ready_to_receive_data ),

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

    .ready_to_receive_CD      (ready_to_receive_CD      ),

    .FU_out_processor_id      (FU_out_processor_id      ),
    .FU_out_data              (FU_out_data              ),
    .FU_out_addr              (FU_out_addr              ),
    .FU_out_data_ready_for_fu (FU_out_data_ready_for_fu ),
    .FU_out_slot_id           (FU_out_slot_id           ),

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
    .out_burst_done 		  (out_burst_done_sch)
);




DMA_top_mttkrp 
#(
    .LEN_ADDR         (LEN_ADDR         ),
    .LEN_DATA_LHS     (LEN_DATA_LHS     ),
    .LEN_PROCESSOR_NO (LEN_PROCESSOR_NO ),
    .LEN_SLOT_ID      (LEN_SLOT_ID      ),
    .LEN_DATA_RHS     (LEN_DATA_RHS     ),
    .PACKT_LEN        (PACKT_LEN        ),
    .NUM_DMA          (NUM_DMA          ),
    .NUM_DMA_BITS     ($clog2(NUM_DMA)  )
)
u_DMA_top_mttkrp(
    .clk                      (clk                      ),
    .rst                      (rst                      ),

    .in_CD_addr               (in_CD_addr_dma               ),
    .in_CD_processor_id       (in_CD_processor_id_dma       ),
    .CD_in_slot_id            (CD_in_slot_id_dma            ),
    .CD_in_pkt_size           (CD_in_pkt_size_dma           ),
    .in_CD_data               (in_CD_data_dma               ),
    .in_CD_wrt                (in_CD_wrt_dma                ),
    .in_CD_addr_en            (in_CD_addr_en_dma            ),
    .in_CD_data_en            (in_CD_data_en_dma            ),

    .FU_ready_to_receive_data (FU_ready_to_receive_data_FU ),

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

    .FU_out_processor_id      (FU_out_processor_id_FU      ),
    .FU_out_data              (FU_out_data_FU              ),
    .FU_out_addr              (FU_out_addr_FU              ),
    .FU_out_data_ready_for_fu (FU_out_data_ready_for_fu_FU ),
    .FU_out_tx_count          (FU_out_tx_count_FU          ),
    .FU_out_slot_id           (FU_out_slot_id_FU           ),
    .ready_to_receive_CD      (ready_to_receive_CD_FU      )
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


ComputePE 
#(
    .TENSOR_WIDTH            (TENSOR_WIDTH            ),
    .TENSOR_DIMENSIONS       (TENSOR_DIMENSIONS       ),
    .FACTOR_MATRIX_WIDTH     (FACTOR_MATRIX_WIDTH     ),
    .RANK_FACTOR_MATRIX      (RANK_FACTOR_MATRIX      ),
    .NUM_INTERNAL_MEM_TENSOR (NUM_INTERNAL_MEM_TENSOR ),
    .TENSOR_DATA_WIDTH       (TENSOR_DATA_WIDTH       ),
    .MODE_TENSOR_BLOCK_WIDTH (MODE_TENSOR_BLOCK_WIDTH ),
    .MODE_TENSOR_ADDR_WIDTH  (MODE_TENSOR_ADDR_WIDTH  ),
    .NUM_OF_SHARDS           (NUM_OF_SHARDS           ),
    .DMA_DATA_WIDTH          (DMA_DATA_WIDTH          ),
    .NUM_COMPUTE_UNITS       (NUM_COMPUTE_UNITS       )
)
u_ComputePE(
    .clk                               (clk                               ),
    .rst                               (rst                               ),

    .begining_of_shard                 (begining_of_shard_pe                 ),
    .end_of_shard                      (end_of_shard_pe                      ),
    .factor_data_ack                   (factor_data_ack_pe                   ),
    .adder_tree_ready_to_receive       (adder_tree_ready_to_receive_pe       ),
    .tensor_element_en                 (tensor_element_en_pe                 ),
    .tensor_element                    (tensor_element_pe                    ),

    .input_factor_matrices_en          (input_factor_matrices_en_pe          ),
    .input_factor_matrices             (input_factor_matrices_pe             ),
    .input_compute_id_factor_matrices  (input_compute_id_factor_matrices_pe  ),

    .output_factor_matrices_addr_en    (output_factor_matrices_addr_en_pe    ),
    .output_factor_matrices_addr       (output_factor_matrices_addr_pe       ),
    .output_compute_id_factor_matrices (output_compute_id_factor_matrices_pe ),
    .op_done_ack                       (op_done_ack_pe                       ),
    .output_to_adder_tree_en           (output_to_adder_tree_en_pe           ),
    .output_to_adder_tree              (output_to_adder_tree_pe              ),
    .reordered_tensor_element_en       (reordered_tensor_element_en_pe       ),
    .reordered_tensor_element          (reordered_tensor_element_pe          )
);



endmodule
