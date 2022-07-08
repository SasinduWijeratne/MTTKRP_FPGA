`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/29/2021 01:38:54 PM
// Design Name: 
// Module Name: mttkrp_scheduler_wrapper_cache
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


module mttkrp_scheduler_wrapper_cache #(
parameter 	LEN_ADDR 			=	 32,
parameter   NUM_CACHES          =     3,
parameter 	LEN_PROCESSOR_NO 	= 	  7,
parameter 	RHS_BURST_LEN 		= 	  8,
parameter 	LEN_DATA_RHS 		= 	512,
parameter   LEN_SLOT_ID         =     7,
parameter   NUM_DMA             =     4,
parameter 	LEN_DATA_LHS 		= 	512

	)
(

input	wire										clk,
input 	wire 										rst,

//Input from Command Decoder
input 	wire 	[NUM_CACHES-1 : 0][LEN_ADDR-1: 0] 					    CD_in_addr,
input 	wire 	[NUM_CACHES-1 : 0][LEN_PROCESSOR_NO-1: 0] 			    CD_in_processor_id,
input 	wire 	[NUM_CACHES-1 : 0][LEN_DATA_LHS-1: 0] 				    CD_in_data,
input 	wire 	[NUM_CACHES-1 : 0]				 					    CD_in_rd_enbl, // LHS enable
input 	wire 	[NUM_CACHES-1 : 0]				 					    CD_in_wr_enbl, // LHS enable
input 	wire 	[NUM_CACHES-1 : 0]				 					    CD_in_wr_enbl_data, // LHS enable
input   wire    [NUM_CACHES-1 : 0][LEN_SLOT_ID-1 : 0]                   CD_in_slot_id,
// input 	wire 	[LEN_BURST_LEN-1: 0] 				CD_burst_len,

//Input from forwarding unit
input 	wire 	[NUM_CACHES-1 : 0]									    FU_ready_to_receive,
input 	wire 	[NUM_CACHES-1 : 0]									    FU_ready_to_receive_data,

//Input from memory interface
input 	wire 	[LEN_DATA_RHS-1: 0] 				                    mem_in_data,
input 	wire 					 					                    mem_in_ready_to_receive, // RHS is accepting data
input 	wire 										                    mem_in_data_ready, // RHS data available

// Input from DMA
input 	wire 	[LEN_ADDR-1: 0] 					                    dma_in_addr,
input 	wire 	[LEN_DATA_RHS-1: 0] 				                    dma_in_data,
input 	wire 										                    dma_in_wrt_enbl_mem,
input 	wire 										                    dma_in_receive_enbl_mem,
input 	wire 										                    dma_in_available_mem,
input   wire    [NUM_DMA-1:0]                                           dma_in_id,
input 	wire 										                    dma_in_burst_done,

//Output to Command Decoder
output 	reg [NUM_CACHES-1 : 0]										    ready_to_receive_CD,

//Output to forwarding unit
output 	wire 	[NUM_CACHES-1 : 0][LEN_PROCESSOR_NO-1: 0] 			    FU_out_processor_id,
output 	reg 	[NUM_CACHES-1 : 0][LEN_DATA_LHS-1: 0] 				    FU_out_data,
output 	wire 	[NUM_CACHES-1 : 0][LEN_ADDR-1: 0] 					    FU_out_addr,
output 	reg 	[NUM_CACHES-1 : 0]									    FU_out_data_ready_for_fu,
output 	wire 	[NUM_CACHES-1 : 0][LEN_SLOT_ID-1: 0] 			        FU_out_slot_id,

//Output to DMA
output 	reg		[LEN_DATA_RHS-1: 0] 				                    dma_out_data,
output  reg     [NUM_DMA-1:0]                                           dma_out_id,
output 	reg						 					                    dma_in_ready_to_receive,
output 	reg											                    dma_out_data_ready,


//Output to memory interface
output 	reg 	[LEN_ADDR-1: 0] 					                    mem_out_addr,
output 	reg 	[LEN_DATA_RHS-1: 0] 				                    mem_out_data,
output  reg 										                    out_wrt_enbl_mem,
output  reg 										                    out_receive_enbl_mem,
output  reg 										                    out_available_mem,
output 	wire 										                    out_burst_done

//Output to stat collect
// output 	reg 	[1:0]                               stat_occupancy // SCH IN full,  Iss full, FU full,

    );

localparam 					RHS_BURST_LEN_SCH 		= 1;

localparam 					DMA_TIME_OUT 			= 1023; 


reg [NUM_CACHES-1 : 0]						ready_to_out_FU; // forward to output fifos
reg 						send_pkt_fr_mem; // receive all the data from rhs

wire 						req_avl_to_send_mem;
wire 	[NUM_CACHES-1 : 0]					input_processor_id_empty;
wire 						input_data_empty;
wire 						input_fifo_addr_empty;
wire 	[NUM_CACHES-1 : 0]					in_wr_enbl_fifo_lhs;

wire 	[NUM_CACHES-1 : 0][LEN_SLOT_ID-1: 0] 		        fifo_inter_slot_id;

wire 						addr_ready_for_fu;
wire 						processor_ready_for_fu;

wire 	[NUM_CACHES-1 : 0]					to_fu_addr_fifo_full;
wire 						to_fu_data_fifo_full;
wire 	[NUM_CACHES-1 : 0]					to_fu_pid_fifo_full;

wire 	[NUM_CACHES-1 : 0]					from_cu_addr_fifo_full;
wire 	[NUM_CACHES-1 : 0]                  from_cu_data_fifo_full;
wire 	[NUM_CACHES-1 : 0]					from_cu_pid_fifo_full;

wire 	[NUM_CACHES-1 : 0]					dirty_pid_wire;

reg 												                ready_send_data_mem = 0;
reg 												                ready_send_data_mem_MRP = 0;
wire 	[NUM_CACHES-1 : 0][LEN_PROCESSOR_NO-1: 0] 					fifo_inter_FU_out_processor_id;
wire 	[LEN_ADDR-1: 0] 							                mem_out_addr_fifo;

reg 	[NUM_DMA-1:0]      							access_type_to_IU_in;
reg 												access_type_wr_en;
reg 												access_type_rd_en;
wire 	[NUM_DMA-1:0]								access_type_to_IU_out;
wire 												access_type_to_IU_full;
wire 												access_type_to_IU_empty;

reg 	[$clog2(DMA_TIME_OUT+1):0]					dma_counter 		= 0;
reg 												dma_timer_out 		= 0;
reg 												dma_timer_out_force = 0;
wire 												dma_timer_out_wire;

reg 	[LEN_DATA_RHS-1: 0] 						                mem_in_data_FU_LHS;
reg  												                mem_in_FU_LHS_wr_en = 0;
reg   	[NUM_CACHES-1 : 0]											mem_in_FU_LHS_rd_en;		
wire  	[NUM_CACHES-1 : 0]											mem_in_data_FU_LHS_full;
wire  	[NUM_CACHES-1 : 0]											mem_in_data_FU_LHS_empty;
reg 	[NUM_CACHES-1 : 0][LEN_DATA_LHS-1: 0] 						mem_data_out_FU_LHS;

wire 	[NUM_CACHES-1 : 0][LEN_DATA_RHS-1: 0] 				        mem_out_data_MRP;

wire                                                                to_cache0_addr_fifo_full;


reg 	[LEN_ADDR-1: 0] 					dma_in_addr_reg;
reg 	[LEN_DATA_RHS-1: 0] 				dma_in_data_reg;
reg 										dma_in_wrt_enbl_mem_reg;
reg 										dma_in_receive_enbl_mem_reg;
reg 										dma_in_available_mem_reg;
reg    [NUM_DMA-1:0]                        dma_in_id_reg;

reg [NUM_CACHES-1 : 0]												          i_peEN;
reg [NUM_CACHES-1 : 0][LEN_PROCESSOR_NO + LEN_SLOT_ID + LEN_ADDR -1 : 0]	 	  PID_pe_in;
reg [NUM_CACHES-1 : 0][LEN_DATA_LHS -1 : 0] 							          Data_pe_in;
reg [NUM_CACHES-1 : 0][LEN_ADDR -1 :0] 								          Address_pe;
reg [NUM_CACHES-1 : 0][LEN_PROCESSOR_NO + LEN_SLOT_ID + LEN_ADDR -1 : 0]       PID_pe_out;
reg [NUM_CACHES-1 : 0][LEN_DATA_LHS -1 : 0] 							          Data_pe_out;
reg [NUM_CACHES-1 : 0]  												          HIT_pe_out;
reg [NUM_CACHES-1 : 0]												          MEM_pe_forward;
reg [NUM_CACHES-1 : 0]												          i_memEN;
reg [NUM_CACHES-1 : 0][LEN_PROCESSOR_NO + LEN_SLOT_ID + LEN_ADDR-1 : 0]        PID_mem_in;
reg [NUM_CACHES-1 : 0][LEN_DATA_LHS -1 : 0] 						              Data_mem_in;
reg [NUM_CACHES-1 : 0][LEN_ADDR -1 : 0] 								          Address_mem_in;
reg [NUM_CACHES-1 : 0][LEN_PROCESSOR_NO + LEN_SLOT_ID + LEN_ADDR-1 : 0] 		  PID_mem_out;
reg [NUM_CACHES-1 : 0][LEN_DATA_LHS -1 : 0] 							          Data_mem_out;
reg [NUM_CACHES-1 : 0][LEN_ADDR -1 :0] 								          Address_mem_out;
reg [NUM_CACHES-1 : 0]												          Flush_mem_out;
reg [NUM_CACHES-1 : 0] 												          cache_miss;
reg [NUM_CACHES-1 : 0]												           o_memEN;

wire 	[NUM_CACHES-1 : 0][LEN_PROCESSOR_NO-1: 0] 					cache_in_processor_id;
wire 	[NUM_CACHES-1 : 0]											cache_in_wr;
wire 	[NUM_CACHES-1 : 0][LEN_SLOT_ID-1: 0] 		        			cache_in_slot_id;
wire 	[NUM_CACHES-1 : 0][LEN_ADDR-1: 0] 							cache_in_addr;
wire  	[NUM_CACHES-1 : 0]											input_processor_id_empty0;
wire  	[NUM_CACHES-1 : 0]											input_fifo_addr_empty0;
wire  	[NUM_CACHES-1 : 0]											input_data_empty0;

reg  	[NUM_CACHES-1 : 0]							                cache_in_addr_en;
reg  	[NUM_CACHES-1 : 0]											cache_in_data_en;
wire  	[NUM_CACHES-1 : 0]											cache_pe_en;

reg 	[NUM_CACHES-1 : 0][LEN_PROCESSOR_NO-1: 0] 					cache_out_processor_id;
reg 	[NUM_CACHES-1 : 0]											cache_out_wr;
reg 	[NUM_CACHES-1 : 0][LEN_SLOT_ID-1: 0] 		        		cache_out_slot_id;
reg 	[LEN_ADDR-1: 0] 							                cache_out_addr;
reg 	[NUM_CACHES-1 : 0][LEN_ADDR-1: 0] 							cache_dummy_addr;

reg  												                cache_out_addr_en;
reg  	[NUM_CACHES-1 : 0]											cache_out_data_en;

wire 	[NUM_CACHES-1 : 0][LEN_PROCESSOR_NO-1: 0] 					cache0_out_processor_id;
wire 	[NUM_CACHES-1 : 0]											dirty_pid_wire0;
wire 	[NUM_CACHES-1 : 0][LEN_SLOT_ID-1: 0] 		        		cache0_out_slot_id;
reg 	[NUM_CACHES-1 : 0][LEN_ADDR-1: 0] 							cache0_out_addr;

wire 	[LEN_ADDR-1: 0] 							                cache0_out_addr00;

reg 	[NUM_CACHES-1 : 0][LEN_PROCESSOR_NO-1: 0] 					hitflush_processor_id;
wire 	[NUM_CACHES-1 : 0]											hitflush_out_wr;
reg 	[NUM_CACHES-1 : 0][LEN_SLOT_ID-1: 0] 		        	    hitflush_out_slot_id;
reg 	[NUM_CACHES-1 : 0][LEN_ADDR-1: 0] 							hitflush_out_addr;

wire 	[NUM_CACHES-1 : 0]											to_cache0_pid_fifo_full;

wire    [NUM_CACHES-1 : 0]                                          from_cu_pid_fifo_full1;
wire    [NUM_CACHES-1 : 0]                                          from_cu_data_fifo_full0;

reg [LEN_DATA_LHS -1 : 0] 							                Data_mem_out_k;
reg [NUM_CACHES-1 : 0]                                              cache_out_addr_en_id;

integer xx;

assign dma_timer_out_wire 	= dma_timer_out | dma_timer_out_force;
assign req_avl_to_send_mem  = (~input_processor_id_empty) & (~input_fifo_addr_empty);
assign out_burst_done = out_wrt_enbl_mem;

genvar i;
integer j;

always @(*) begin
    for ( j=0; j<NUM_CACHES; j = j + 1) begin

        ready_to_receive_CD[j] 			= ~((from_cu_pid_fifo_full[j]) | (from_cu_data_fifo_full[j]));

        FU_out_data[j]                  = mem_data_out_FU_LHS[j];
        FU_out_data_ready_for_fu[j]     = (~mem_in_data_FU_LHS_empty[j]);
        mem_in_FU_LHS_rd_en[j]          = FU_ready_to_receive_data[j];
        ready_to_out_FU[j] 		        = send_pkt_fr_mem & ((~(to_fu_data_fifo_full)) & (~(to_cache0_addr_fifo_full)) & (~(to_cache0_pid_fifo_full[j])));


        // Need to change
        cache_in_addr_en[j] 	            = (~o_memEN[j]) & (~input_processor_id_empty0[j]) & (~input_fifo_addr_empty0[j]) & (~to_fu_addr_fifo_full[j]);
        PID_pe_in[j] 			            = {cache_in_processor_id[j],cache_in_slot_id[j],cache_in_addr[j]};
        Address_pe[j] 			            = {~cache_in_wr[j],cache_in_addr[j]};
        i_peEN[j] 				            = cache_in_addr_en[j];
        cache_in_data_en[j] 	            = cache_in_wr[j] & cache_in_addr_en[j] & (~input_data_empty0[j]);

        {cache_out_processor_id[j],cache_out_slot_id[j],cache_dummy_addr[j]} 	= PID_mem_out[j];
        cache_out_wr[j] 												    = Flush_mem_out[j];
        

        i_memEN[j]         = mem_in_FU_LHS_wr_en;
        PID_mem_in[j]      = {cache0_out_processor_id[j], cache0_out_slot_id[j],cache0_out_addr[j]};
        Data_mem_in[j]     = mem_in_data_FU_LHS[j];
        Address_mem_in[j]  = cache0_out_addr[j];

        {hitflush_processor_id[j],hitflush_out_slot_id[j],hitflush_out_addr[j]} = PID_pe_out[j];
        
    end
end

generate;
    for (i=0; i<NUM_CACHES; i = i + 1) begin: CACHE_COPIES
        // Following fifos gather all the data from CD
        processor_id_n_wr_en FIFO_inst_LHS_input_processor_id0 ( 	.clk(clk),
                                                                    .din({CD_in_processor_id[i],CD_in_wr_enbl[i],CD_in_slot_id[i]}),
                                                                    .wr_en(CD_in_wr_enbl[i]|CD_in_rd_enbl[i]),
                                                                    .rd_en(cache_in_addr_en[i]),
                                                                    .dout({cache_in_processor_id[i],cache_in_wr[i],cache_in_slot_id[i]}),
                                                                    .full(from_cu_pid_fifo_full[i]),
                                                                    .empty(input_processor_id_empty0[i])
                                                                );

        fifo_addr inst_LHS_input_fifo_addr0 ( 	.rd_clk(clk),
                                                .wr_clk(clk),
                                                .din(CD_in_addr[i]),
                                                .wr_en(CD_in_wr_enbl[i]|CD_in_rd_enbl[i]),
                                                .rd_en(cache_in_addr_en[i]), // mem_in_ready_to_receive
                                                .dout(cache_in_addr[i]),
                                                .full(from_cu_addr_fifo_full[i]),
                                                .empty(input_fifo_addr_empty0[i])
                                            );

        // Change to asymmetric data widths FIFO
        fifo_data inst_LHS_input_fifo_data0 ( 	.clk(clk),
                                                .din(CD_in_data[i]), // take 64 bit from CD
                                                .wr_en(CD_in_wr_enbl_data[i]),
                                                .rd_en(cache_in_data_en[i]), // mem_in_ready_to_receive
                                                .dout(Data_pe_in[i]), // Convert 512 bit to Memory Controller
                                                .full(from_cu_data_fifo_full[i]),
                                                .empty(input_data_empty0[i])
                                            );

        processor_id_n_wr_en FIFO_inst_LHS_input_processor_id1 ( 	.clk(clk),
                                                                    .din({cache_out_processor_id[i],cache_out_wr,cache_out_slot_id[i]}),
                                                                    .wr_en(cache_out_addr_en_id[i]),
                                                                    .rd_en(ready_to_out_FU[i]),
                                                                    .dout({fifo_inter_FU_out_processor_id[i],in_wr_enbl_fifo_lhs[i],fifo_inter_slot_id[i]}),
                                                                    .full(from_cu_pid_fifo_full1[i]),
                                                                    .empty(input_processor_id_empty[i])
                                                                );

        Cache u_Cache(
            .clk             (clk),
            .RST             (~rst),
            .i_peEN          (i_peEN[i]),
            .PID_pe_in       (PID_pe_in[i]),
            .Data_pe_in      (Data_pe_in[i]),
            .Address_pe      (Address_pe[i]),
            .PID_pe_out      (PID_pe_out[i]),
            .Data_pe_out     (Data_pe_out[i]),
            .HIT_pe_out      (HIT_pe_out[i]),
            .MEM_pe_forward  (MEM_pe_forward[i]),
            .i_memEN         (i_memEN[i]),
            .PID_mem_in      (PID_mem_in[i]),
            .Data_mem_in     (Data_mem_in[i]),
            .Address_mem_in  (Address_mem_in[i]),
            .PID_mem_out     (PID_mem_out[i]),
            .Data_mem_out    (Data_mem_out[i]),
            .Address_mem_out (Address_mem_out[i]),
            .Flush_mem_out   (Flush_mem_out[i]),
            .cache_miss   	 (cache_miss[i]),
            .o_memEN         (o_memEN[i])
        );

// Following fifos store the values to create the header FLITs of DRAM return transactions 
processor_id_n_wr_en FIFO_inst_LHS_output_processor_id_cache ( 	.clk(clk),
    														.din({fifo_inter_FU_out_processor_id[i],1'b0,fifo_inter_slot_id[i]}),
    														.wr_en((~out_wrt_enbl_mem) & ready_to_out_FU[i]),
    														.rd_en(FU_ready_to_receive[i]),
    														.dout({cache0_out_processor_id[i],dirty_pid_wire0[i],cache0_out_slot_id[i]}),
    														.full(to_cache0_pid_fifo_full[i]),
    														.empty()
  														);

processor_id_n_wr_en FIFO_inst_LHS_output_processor_id ( 	.clk(clk),
    														.din({hitflush_processor_id[i],1'b0,hitflush_out_slot_id[i]}),
    														.wr_en(MEM_pe_forward[i]),
    														.rd_en(mem_in_FU_LHS_wr_en),
    														.dout({FU_out_processor_id[i],dirty_pid_wire[i],FU_out_slot_id[i]}),
    														.full(to_fu_pid_fifo_full[i]),
    														.empty()
  														);

fifo_addr inst_LHS_output_fifo_addr ( 	.rd_clk(clk),
                                        .wr_clk(clk),
    									.din(hitflush_out_addr[i]),
    									.wr_en(MEM_pe_forward[i]),
    									.rd_en(mem_in_FU_LHS_wr_en),
    									.dout(FU_out_addr[i]),
    									.full(to_fu_addr_fifo_full[i]),
    									.empty()
									);

fifo_data_FU inst_LHS_fifo_data_FU ( 	.clk(clk),
                                        .srst(~rst),
    									.din(Data_pe_out[i]),
    									.wr_en(MEM_pe_forward[i]),
    									.rd_en(mem_in_FU_LHS_rd_en[i]),
    									.dout(mem_data_out_FU_LHS[i]),
    									.full(mem_in_data_FU_LHS_full[i]),
    									.empty(mem_in_data_FU_LHS_empty[i])
  									);
    end
endgenerate


always @(posedge clk) begin
    cache_out_data_en           = 0;
    cache_out_addr_en           = 0;
    cache_out_addr_en_id        = 0;
    for (xx = 0; xx < NUM_CACHES; xx = xx +1) begin
        if(Flush_mem_out[xx]) begin
            cache_out_data_en   = 1;
            Data_mem_out_k      = Data_mem_out[xx];
        end
        if (cache_miss[xx]|Flush_mem_out[xx]) begin
            cache_out_addr_en       = 1;
            cache_out_addr          = Flush_mem_out[xx] ? Address_mem_out[xx] : PID_mem_out[xx][LEN_ADDR-1: 0];
            cache_out_addr_en_id    = (1 << xx);
        end
    end
end

always @(*) begin
    for (xx = 0; xx < NUM_CACHES; xx = xx +1) begin
        cache0_out_addr[xx]     <= cache0_out_addr00;
    end
end

fifo_data inst_LHS_input_fifo_data1 ( 	.clk(clk),
                                    .din(Data_mem_out_k), // take 64 bit from CD
                                    .wr_en(cache_out_data_en),
                                    .rd_en(ready_send_data_mem_MRP), // mem_in_ready_to_receive
                                    .dout(mem_out_data_MRP), // Convert 512 bit to Memory Controller
                                    .full(from_cu_data_fifo_full0),
                                    .empty(input_data_empty)
                                );

fifo_addr inst_LHS_input_fifo_addr1 ( 	.rd_clk(clk),
                                        .wr_clk(clk),
    									.din(cache_out_addr),
    									.wr_en(cache_out_addr_en),
    									.rd_en(ready_to_out_FU), // mem_in_ready_to_receive
    									.dout(mem_out_addr_fifo),
    									.full(),
    									.empty(input_fifo_addr_empty)
  									);

fifo_addr inst_LHS_output_fifo_addr_cache ( .rd_clk(clk),
                                        .wr_clk(clk),
    									.din(mem_out_addr_fifo),
    									.wr_en((~out_wrt_enbl_mem) & ready_to_out_FU),
    									.rd_en(&FU_ready_to_receive),
    									.dout(cache0_out_addr00),
    									.full(to_cache0_addr_fifo_full),
    									.empty()
  									);




// Cache u_Cache(
// 	.clk             (clk),
// 	.RST             (~rst),
// 	.i_peEN          (i_peEN),
// 	.PID_pe_in       (PID_pe_in),
// 	.Data_pe_in      (Data_pe_in),
// 	.Address_pe      (Address_pe),
// 	.PID_pe_out      (PID_pe_out),
// 	.Data_pe_out     (Data_pe_out),
// 	.HIT_pe_out      (HIT_pe_out),
// 	.MEM_pe_forward  (MEM_pe_forward),
// 	.i_memEN         (i_memEN),
// 	.PID_mem_in      (PID_mem_in),
// 	.Data_mem_in     (Data_mem_in),
// 	.Address_mem_in  (Address_mem_in),
// 	.PID_mem_out     (PID_mem_out),
// 	.Data_mem_out    (Data_mem_out),
// 	.Address_mem_out (Address_mem_out),
// 	.Flush_mem_out   (Flush_mem_out),
// 	.cache_miss   	 (cache_miss),
// 	.o_memEN         (o_memEN)
// );


// One bit indicating from where the request should be mapped to (i.e., DMA or not)
// Depth = maximum outstanding requests in Issue Unit 

fifo_access_type inst_access_type 	( 	.clk(clk),
    									.din(access_type_to_IU_in),
    									.wr_en(access_type_wr_en),
    									.rd_en(access_type_rd_en),
    									.dout(access_type_to_IU_out),
    									.full(access_type_to_IU_full),
    									.empty(access_type_to_IU_empty)
  									);

assign to_fu_data_fifo_full = &mem_in_data_FU_LHS_full;

always@(*) begin
        dma_in_addr_reg                 <= dma_in_addr;
        dma_in_data_reg                 <= dma_in_data;
        dma_in_wrt_enbl_mem_reg         <= dma_in_wrt_enbl_mem;
        dma_in_receive_enbl_mem_reg     <= dma_in_receive_enbl_mem;
        dma_in_available_mem_reg        <= dma_in_available_mem;
        dma_in_id_reg                   <= dma_in_id;
end

always @(*) begin: proc_mem_in
	if (~rst) begin
		access_type_rd_en 	       <= 0;
		dma_out_data 		       <= mem_in_data;
		mem_in_data_FU_LHS	       <= mem_in_data;
		dma_out_data_ready 	       <= 0;
		mem_in_FU_LHS_wr_en        <= 0;
		out_receive_enbl_mem       <= 0;
		dma_out_id                 <= {(NUM_DMA){1'bx}};
	end else begin

		access_type_rd_en 	       <= 0;
		dma_out_data 		       <= mem_in_data;
		mem_in_data_FU_LHS 	       <= mem_in_data;
		dma_out_data_ready 	       <= 0;
		mem_in_FU_LHS_wr_en        <= 0;
		out_receive_enbl_mem       <= 0;
		dma_out_id                 <= access_type_to_IU_out;


		if(mem_in_data_ready) begin
			if ((access_type_to_IU_out != 0)) begin // DMA
				if(dma_in_receive_enbl_mem_reg) begin
					access_type_rd_en 		<= 1;
					dma_out_data_ready 		<= 1;
					out_receive_enbl_mem 	<= 1;
				end
			end
			else begin // MRP
				if(~(&mem_in_data_FU_LHS_full)) begin
					access_type_rd_en 		<= 1;
					mem_in_FU_LHS_wr_en 	<= 1;
					out_receive_enbl_mem 	<= 1;
				end
			end
		end
	end
end


always @(*) begin : proc_mem_out_fsm
	if(~rst) begin

		send_pkt_fr_mem 		<= 0;
		out_available_mem 		<= 0;
		out_wrt_enbl_mem 		<= 0;
		ready_send_data_mem 	<= 0;
		ready_send_data_mem_MRP <= 0;
		mem_out_addr           	<= mem_out_addr_fifo;
		mem_out_data			<= mem_out_data_MRP;
		access_type_to_IU_in 	<= {(NUM_DMA){1'bx}};
		dma_in_ready_to_receive <= 0;
		access_type_wr_en       <= 0;

	end else begin

		send_pkt_fr_mem 		<= 0;
		out_available_mem 		<= 0;
		out_wrt_enbl_mem 		<= 0;
		ready_send_data_mem 	<= 0;
		ready_send_data_mem_MRP <= 0;
		mem_out_addr           	<= mem_out_addr_fifo;
		mem_out_data			<= mem_out_data_MRP;
		dma_in_ready_to_receive <= 0;
		access_type_wr_en       <= 0;

		if (dma_timer_out_wire & dma_in_available_mem_reg) begin
			out_wrt_enbl_mem       	<= dma_in_wrt_enbl_mem_reg;
		  	if(mem_in_ready_to_receive) begin
				out_available_mem 		<= 1;
				mem_out_addr            <= dma_in_addr_reg;
				dma_in_ready_to_receive <= 1;


				if(dma_in_wrt_enbl_mem_reg) begin
					ready_send_data_mem 	<= 1;
					mem_out_data 			<= dma_in_data_reg;
				end else begin
			    	access_type_to_IU_in 	<= dma_in_id_reg;
			    	access_type_wr_en       <= 1;
				end
			end
		end
		else if (((~to_fu_data_fifo_full) & (~to_cache0_addr_fifo_full) & (~to_cache0_pid_fifo_full))) begin // assume: priority -> data read, common bus in memory side
			out_wrt_enbl_mem       	<= &in_wr_enbl_fifo_lhs;
			if(mem_in_ready_to_receive) begin
				if(req_avl_to_send_mem) begin  

					if(&in_wr_enbl_fifo_lhs) begin
				    	if(~input_data_empty) begin
				    

    				    	send_pkt_fr_mem 		<= 1;
    				    	out_available_mem 		<= 1;
    				    	mem_out_addr            <= mem_out_addr_fifo; 
    				    								
					   		ready_send_data_mem 	<= 1;
					   		ready_send_data_mem_MRP <= 1;
					   		mem_out_data 			<= mem_out_data_MRP;
				    	end

					end 
					else begin

				    	send_pkt_fr_mem 		<= 1;
				    	out_available_mem 		<= 1;
				    	mem_out_addr            <= mem_out_addr_fifo; 
				    	access_type_to_IU_in 	<= 0;
				    	access_type_wr_en       <= 1;
				    
				    
					end
				end
			end
		end
		else if (dma_in_available_mem_reg) begin
			out_wrt_enbl_mem       			<= dma_in_wrt_enbl_mem_reg;
			if(mem_in_ready_to_receive) begin
				out_available_mem 			<= 1;
				mem_out_addr            	<= dma_in_addr_reg;
				dma_in_ready_to_receive 	<= 1;
			
				if(dma_in_wrt_enbl_mem_reg) begin
					ready_send_data_mem 	<= 1;
					mem_out_data 			<= dma_in_data_reg;
				end
				else begin
			    	access_type_to_IU_in 		<= dma_in_id_reg;
			    	access_type_wr_en           <= 1;
				end
			end
		end
	end
end


always @(posedge clk) begin : proc_mem_out
	if(~rst) begin
		dma_timer_out_force 	<= 0;
	end else begin

		if ((~(mem_in_ready_to_receive & dma_timer_out_wire & dma_in_available_mem_reg)) & (mem_in_ready_to_receive & ((~to_fu_data_fifo_full) & (~to_cache0_addr_fifo_full) & (~to_cache0_pid_fifo_full)))) begin // assume: priority -> data read, common bus in memory side
			if(req_avl_to_send_mem) begin  

				if(&in_wr_enbl_fifo_lhs) begin
				    if(~input_data_empty) begin
				    
    				    dma_timer_out_force 	<= 0;
				    end
				end 
				else begin
				    dma_timer_out_force 	<= 0;
				end
			end
		end
		else if (mem_in_ready_to_receive & dma_in_available_mem_reg) begin
			dma_timer_out_force 		<= 1;
		end
	end
end


always @(posedge clk) begin
	if(~dma_in_available_mem_reg) begin
		dma_counter 	<= 0;
		dma_timer_out 	<= 0;
	end else begin
		if (dma_counter == DMA_TIME_OUT) begin
			dma_timer_out <= 1;
		end else begin
			dma_counter <= dma_counter + 1'b1;
		end
	end 
end


// stat occupancy
// SCH IN full,  Iss full, FU full,
// always @(posedge clk) begin
//     if(from_cu_addr_fifo_full) begin
//         stat_occupancy  <= 3;
//     end else if(~(mem_in_ready_to_receive)) begin
//         stat_occupancy  <= 2;
//     end else if(to_fu_addr_fifo_full) begin 
//         stat_occupancy  <= 1;
//     end else begin
//         stat_occupancy  <= 0;
//     end 
// end

endmodule