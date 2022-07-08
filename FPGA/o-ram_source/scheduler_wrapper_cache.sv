`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: pgroup @ usc
// Engineer: Sasindu Wijeratne
// 
// Create Date: 06/19/2020 09:30:09 PM
// Design Name: 
// Module Name: scheduler_wrapper
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


module scheduler_wrapper_cache #(
parameter 	LEN_ADDR 			=	 32,
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
input 	wire 	[LEN_ADDR-1: 0] 					CD_in_addr,
input 	wire 	[LEN_PROCESSOR_NO-1: 0] 			CD_in_processor_id,
input 	wire 	[LEN_DATA_LHS-1: 0] 				CD_in_data,
input 	wire 					 					CD_in_rd_enbl, // LHS enable
input 	wire 					 					CD_in_wr_enbl, // LHS enable
input 	wire 					 					CD_in_wr_enbl_data, // LHS enable
input   wire     [LEN_SLOT_ID-1 : 0]                CD_in_slot_id,
// input 	wire 	[LEN_BURST_LEN-1: 0] 				CD_burst_len,

//Input from forwarding unit
input 	wire 										FU_ready_to_receive,
input 	wire 										FU_ready_to_receive_data,

//Input from memory interface
input 	wire 	[LEN_DATA_RHS-1: 0] 				mem_in_data,
input 	wire 					 					mem_in_ready_to_receive, // RHS is accepting data
input 	wire 										mem_in_data_ready, // RHS data available

// Input from DMA
input 	wire 	[LEN_ADDR-1: 0] 					dma_in_addr,
input 	wire 	[LEN_DATA_RHS-1: 0] 				dma_in_data,
input 	wire 										dma_in_wrt_enbl_mem,
input 	wire 										dma_in_receive_enbl_mem,
input 	wire 										dma_in_available_mem,
input   wire    [NUM_DMA-1:0]                       dma_in_id,
input 	wire 										dma_in_burst_done,

//Output to Command Decoder
output 	wire 										ready_to_receive_CD,

//Output to forwarding unit
output 	wire 	[LEN_PROCESSOR_NO-1: 0] 			FU_out_processor_id,
output 	wire 	[LEN_DATA_LHS-1: 0] 				FU_out_data,
output 	wire 	[LEN_ADDR-1: 0] 					FU_out_addr,
output 	wire 										FU_out_data_ready_for_fu,
output 	wire 	[LEN_SLOT_ID-1: 0] 			        FU_out_slot_id,

//Output to DMA
output 	reg		[LEN_DATA_RHS-1: 0] 				dma_out_data,
output  reg     [NUM_DMA-1:0]                       dma_out_id,
output 	reg						 					dma_in_ready_to_receive,
output 	reg											dma_out_data_ready,


//Output to memory interface
output 	reg 	[LEN_ADDR-1: 0] 					mem_out_addr,
output 	reg 	[LEN_DATA_RHS-1: 0] 				mem_out_data,
output  reg 										out_wrt_enbl_mem,
output  reg 										out_receive_enbl_mem,
output  reg 										out_available_mem,
output 	wire 										out_burst_done,

//Output to stat collect
output 	reg 	[1:0]                               stat_occupancy // SCH IN full,  Iss full, FU full,

    );

localparam 					RHS_BURST_LEN_SCH 		= 1;

localparam 					DMA_TIME_OUT 			= 1023; 


wire 						ready_to_out_FU; // forward to output fifos
reg 						send_pkt_fr_mem; // receive all the data from rhs

wire 						req_avl_to_send_mem;
wire 						input_processor_id_empty;
wire 						input_data_empty;
wire 						input_fifo_addr_empty;
wire 						in_wr_enbl_fifo_lhs;

wire 	[LEN_SLOT_ID-1: 0] 		        fifo_inter_slot_id;

wire 						addr_ready_for_fu;
wire 						processor_ready_for_fu;

wire 						to_fu_addr_fifo_full;
wire 						to_fu_data_fifo_full;
wire 						to_fu_pid_fifo_full;

wire 						from_cu_addr_fifo_full;
wire 						from_cu_data_fifo_full;
wire 						from_cu_pid_fifo_full;

wire 						dirty_pid_wire;

reg 												ready_send_data_mem = 0;
reg 												ready_send_data_mem_MRP = 0;
wire 	[LEN_PROCESSOR_NO-1: 0] 					fifo_inter_FU_out_processor_id;
wire 	[LEN_ADDR-1: 0] 							mem_out_addr_fifo;

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

reg 	[LEN_DATA_RHS-1: 0] 						mem_in_data_FU_LHS;
reg  												mem_in_FU_LHS_wr_en = 0;
wire   												mem_in_FU_LHS_rd_en;		
wire  												mem_in_data_FU_LHS_full;
wire  												mem_in_data_FU_LHS_empty;
reg 	[LEN_DATA_LHS-1: 0] 						mem_data_out_FU_LHS;

wire 	[LEN_DATA_RHS-1: 0] 				        mem_out_data_MRP;


reg 	[LEN_ADDR-1: 0] 					dma_in_addr_reg;
reg 	[LEN_DATA_RHS-1: 0] 				dma_in_data_reg;
reg 										dma_in_wrt_enbl_mem_reg;
reg 										dma_in_receive_enbl_mem_reg;
reg 										dma_in_available_mem_reg;
reg    [NUM_DMA-1:0]                        dma_in_id_reg;

wire 												          i_peEN;
wire [LEN_PROCESSOR_NO + LEN_SLOT_ID + LEN_ADDR -1 : 0]	 	  PID_pe_in;
wire [LEN_DATA_LHS -1 : 0] 							          Data_pe_in;
wire [LEN_ADDR -1 :0] 								          Address_pe;
wire [LEN_PROCESSOR_NO + LEN_SLOT_ID + LEN_ADDR -1 : 0]       PID_pe_out;
wire [LEN_DATA_LHS -1 : 0] 							          Data_pe_out;
wire   												          HIT_pe_out;
wire 												          MEM_pe_forward;
wire 												          i_memEN;
wire [LEN_PROCESSOR_NO + LEN_SLOT_ID + LEN_ADDR-1 : 0]        PID_mem_in;
wire [LEN_DATA_LHS -1 : 0] 						              Data_mem_in;
wire [LEN_ADDR -1 : 0] 								          Address_mem_in;
wire [LEN_PROCESSOR_NO + LEN_SLOT_ID + LEN_ADDR-1 : 0] 		  PID_mem_out;
wire [LEN_DATA_LHS -1 : 0] 							          Data_mem_out;
wire [LEN_ADDR -1 :0] 								          Address_mem_out;
wire  												          Flush_mem_out;
wire  												          cache_miss;
wire 												           o_memEN;

wire 	[LEN_PROCESSOR_NO-1: 0] 					cache_in_processor_id;
wire 												cache_in_wr;
wire 	[LEN_SLOT_ID-1: 0] 		        			cache_in_slot_id;
wire 	[LEN_ADDR-1: 0] 							cache_in_addr;
wire  												input_processor_id_empty0;
wire  												input_fifo_addr_empty0;
wire  												input_data_empty0;

wire  												cache_in_addr_en;
wire  												cache_in_data_en;
wire  												cache_pe_en;

wire 	[LEN_PROCESSOR_NO-1: 0] 					cache_out_processor_id;
wire 												cache_out_wr;
wire 	[LEN_SLOT_ID-1: 0] 		        			cache_out_slot_id;
wire 	[LEN_ADDR-1: 0] 							cache_out_addr;
wire 	[LEN_ADDR-1: 0] 							cache_dummy_addr;

wire  												cache_out_addr_en;
wire  												cache_out_data_en;

wire 	[LEN_PROCESSOR_NO-1: 0] 					cache0_out_processor_id;
wire 												dirty_pid_wire0;
wire 	[LEN_SLOT_ID-1: 0] 		        			cache0_out_slot_id;
wire 	[LEN_ADDR-1: 0] 							cache0_out_addr;

wire 	[LEN_PROCESSOR_NO-1: 0] 					hitflush_processor_id;
wire 												hitflush_out_wr;
wire 	[LEN_SLOT_ID-1: 0] 		        			hitflush_out_slot_id;
wire 	[LEN_ADDR-1: 0] 							hitflush_out_addr;

wire 												to_cache0_pid_fifo_full;


assign dma_timer_out_wire 	= dma_timer_out | dma_timer_out_force;

assign ready_to_out_FU 		= send_pkt_fr_mem & ((~to_fu_data_fifo_full) & (~to_cache0_addr_fifo_full) & (~to_cache0_pid_fifo_full));
assign req_avl_to_send_mem  = (~input_processor_id_empty) & (~input_fifo_addr_empty);

assign ready_to_receive_CD 			= ~((from_cu_pid_fifo_full) | (from_cu_addr_fifo_full) | from_cu_data_fifo_full);
assign out_burst_done = out_wrt_enbl_mem;

assign FU_out_data = mem_data_out_FU_LHS;
assign FU_out_data_ready_for_fu  = (~mem_in_data_FU_LHS_empty);
assign mem_in_FU_LHS_rd_en= FU_ready_to_receive_data;

// Following fifos gather all the data from CD
processor_id_n_wr_en FIFO_inst_LHS_input_processor_id0 ( 	.clk(clk),
    														.din({CD_in_processor_id,CD_in_wr_enbl,CD_in_slot_id}),
    														.wr_en(CD_in_wr_enbl|CD_in_rd_enbl),
    														.rd_en(cache_in_addr_en),
    														.dout({cache_in_processor_id,cache_in_wr,cache_in_slot_id}),
    														.full(from_cu_pid_fifo_full),
    														.empty(input_processor_id_empty0)
  														);

processor_id_n_wr_en FIFO_inst_LHS_input_processor_id1 ( 	.clk(clk),
    														.din({cache_out_processor_id,cache_out_wr,cache_out_slot_id}),
    														.wr_en(cache_out_addr_en),
    														.rd_en(ready_to_out_FU),
    														.dout({fifo_inter_FU_out_processor_id,in_wr_enbl_fifo_lhs,fifo_inter_slot_id}),
    														.full(from_cu_pid_fifo_full1),
    														.empty(input_processor_id_empty)
  														);

fifo_addr inst_LHS_input_fifo_addr0 ( 	.rd_clk(clk),
                                        .wr_clk(clk),
    									.din(CD_in_addr),
    									.wr_en(CD_in_wr_enbl|CD_in_rd_enbl),
    									.rd_en(cache_in_addr_en), // mem_in_ready_to_receive
    									.dout(cache_in_addr),
    									.full(from_cu_addr_fifo_full),
    									.empty(input_fifo_addr_empty0)
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


// Change to asymmetric data widths FIFO
fifo_data inst_LHS_input_fifo_data0 ( 	.clk(clk),
    									.din(CD_in_data), // take 64 bit from CD
    									.wr_en(CD_in_wr_enbl_data),
    									.rd_en(cache_in_data_en), // mem_in_ready_to_receive
    									.dout(Data_pe_in), // Convert 512 bit to Memory Controller
    									.full(from_cu_data_fifo_full),
    									.empty(input_data_empty0)
  									);

fifo_data inst_LHS_input_fifo_data1 ( 	.clk(clk),
    									.din(Data_mem_out), // take 64 bit from CD
    									.wr_en(cache_out_data_en),
    									.rd_en(ready_send_data_mem_MRP), // mem_in_ready_to_receive
    									.dout(mem_out_data_MRP), // Convert 512 bit to Memory Controller
    									.full(from_cu_data_fifo_full0),
    									.empty(input_data_empty)
  									);


// Following fifos store the values to create the header FLITs of DRAM return transactions 
processor_id_n_wr_en FIFO_inst_LHS_output_processor_id_cache ( 	.clk(clk),
    														.din({fifo_inter_FU_out_processor_id,1'b0,fifo_inter_slot_id}),
    														.wr_en((~out_wrt_enbl_mem) & ready_to_out_FU),
    														.rd_en(FU_ready_to_receive),
    														.dout({cache0_out_processor_id,dirty_pid_wire0,cache0_out_slot_id}),
    														.full(to_cache0_pid_fifo_full),
    														.empty()
  														);

fifo_addr inst_LHS_output_fifo_addr_cache ( .rd_clk(clk),
                                        .wr_clk(clk),
    									.din(mem_out_addr_fifo),
    									.wr_en((~out_wrt_enbl_mem) & ready_to_out_FU),
    									.rd_en(FU_ready_to_receive),
    									.dout(cache0_out_addr),
    									.full(to_cache0_addr_fifo_full),
    									.empty()
  									);

processor_id_n_wr_en FIFO_inst_LHS_output_processor_id ( 	.clk(clk),
    														.din({hitflush_processor_id,1'b0,hitflush_out_slot_id}),
    														.wr_en(MEM_pe_forward),
    														.rd_en(mem_in_FU_LHS_wr_en),
    														.dout({FU_out_processor_id,dirty_pid_wire,FU_out_slot_id}),
    														.full(to_fu_pid_fifo_full),
    														.empty()
  														);

fifo_addr inst_LHS_output_fifo_addr ( 	.rd_clk(clk),
                                        .wr_clk(clk),
    									.din(hitflush_out_addr),
    									.wr_en(MEM_pe_forward),
    									.rd_en(mem_in_FU_LHS_wr_en),
    									.dout(FU_out_addr),
    									.full(to_fu_addr_fifo_full),
    									.empty()
									);


fifo_data_FU inst_LHS_fifo_data_FU ( 	.clk(clk),
                                        .srst(~rst),
    									.din(Data_pe_out),
    									.wr_en(MEM_pe_forward),
    									.rd_en(mem_in_FU_LHS_rd_en),
    									.dout(mem_data_out_FU_LHS),
    									.full(mem_in_data_FU_LHS_full),
    									.empty(mem_in_data_FU_LHS_empty)
  									);

// Need to change
assign cache_in_addr_en 	= (~o_memEN) & (~input_processor_id_empty0) & (~input_fifo_addr_empty0) & (~to_fu_addr_fifo_full);
assign PID_pe_in 			= {cache_in_processor_id,cache_in_slot_id,cache_in_addr};
assign Address_pe 			= {~cache_in_wr,cache_in_addr};
assign i_peEN 				= cache_in_addr_en;
assign cache_in_data_en 	= cache_in_wr & cache_in_addr_en & (~input_data_empty0);

assign {cache_out_processor_id,cache_out_slot_id,cache_dummy_addr} 	= PID_mem_out;
assign cache_out_wr 												= Flush_mem_out;
assign cache_out_addr 												= Flush_mem_out ? Address_mem_out : PID_mem_out[LEN_ADDR-1: 0];
assign cache_out_addr_en 											= cache_miss|Flush_mem_out;
assign cache_out_data_en 											= Flush_mem_out;

assign i_memEN = mem_in_FU_LHS_wr_en ;
assign PID_mem_in = {cache0_out_processor_id, cache0_out_slot_id,cache0_out_addr};
assign Data_mem_in = mem_in_data_FU_LHS;
assign Address_mem_in = cache0_out_addr;

assign {hitflush_processor_id,hitflush_out_slot_id,hitflush_out_addr} = PID_pe_out;

Cache u_Cache(
	.clk             (clk),
	.RST             (~rst),
	.i_peEN          (i_peEN),
	.PID_pe_in       (PID_pe_in),
	.Data_pe_in      (Data_pe_in),
	.Address_pe      (Address_pe),
	.PID_pe_out      (PID_pe_out),
	.Data_pe_out     (Data_pe_out),
	.HIT_pe_out      (HIT_pe_out),
	.MEM_pe_forward  (MEM_pe_forward),
	.i_memEN         (i_memEN),
	.PID_mem_in      (PID_mem_in),
	.Data_mem_in     (Data_mem_in),
	.Address_mem_in  (Address_mem_in),
	.PID_mem_out     (PID_mem_out),
	.Data_mem_out    (Data_mem_out),
	.Address_mem_out (Address_mem_out),
	.Flush_mem_out   (Flush_mem_out),
	.cache_miss   	 (cache_miss),
	.o_memEN         (o_memEN)
);


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

assign to_fu_data_fifo_full = mem_in_data_FU_LHS_full;

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
				if(~mem_in_data_FU_LHS_full) begin
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
			out_wrt_enbl_mem       	<= in_wr_enbl_fifo_lhs;
			if(mem_in_ready_to_receive) begin
				if(req_avl_to_send_mem) begin  

					if(in_wr_enbl_fifo_lhs) begin
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

				if(in_wr_enbl_fifo_lhs) begin
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
always @(posedge clk) begin
    if(from_cu_addr_fifo_full) begin
        stat_occupancy  <= 3;
    end else if(~(mem_in_ready_to_receive)) begin
        stat_occupancy  <= 2;
    end else if(to_fu_addr_fifo_full) begin 
        stat_occupancy  <= 1;
    end else begin
        stat_occupancy  <= 0;
    end 
end

endmodule
