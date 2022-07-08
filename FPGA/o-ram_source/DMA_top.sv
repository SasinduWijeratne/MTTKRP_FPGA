`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/16/2021 09:12:45 PM
// Design Name: 
// Module Name: DMA_top
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


module DMA_top #(
parameter 	LEN_ADDR 			=	 32,
parameter 	LEN_DATA_LHS 		= 	 512,
parameter 	LEN_PROCESSOR_NO 	= 	  7,
parameter   LEN_SLOT_ID         =     7,
parameter 	LEN_DATA_RHS 		= 	512,
parameter   PACKT_LEN           =    13,
parameter   NUM_DMA             =     4,
parameter   NUM_DMA_BITS        = $clog2(NUM_DMA)
    )(
input	wire										clk,
input 	wire 										rst,

//input from Command Decoder
input  wire 	[LEN_ADDR-1: 0] 					in_CD_addr,
input  wire 	[LEN_PROCESSOR_NO-1: 0] 			in_CD_processor_id,
input  wire     [LEN_SLOT_ID-1 : 0]                 CD_in_slot_id,
input  wire     [PACKT_LEN-1 : 0]                   CD_in_pkt_size,
input  wire 	[LEN_DATA_LHS-1: 0] 				in_CD_data,
input  wire 										in_CD_wrt,
input  wire 										in_CD_addr_en,
input  wire                                         in_CD_addr_ctrl_en,
input  wire 										in_CD_data_en,
// input  wire 										in_CD_receive_enbl,
input  wire                                         in_CD_dma_start, 

//Input from forwarding unit
// input 	wire 										FU_ready_to_receive,
input 	wire 										    FU_ready_to_receive_data,

//Input from memory interface
input 	wire 	[LEN_DATA_RHS-1: 0] 				    mem_in_data,
input   wire    [NUM_DMA-1:0]                           mem_in_id,
input 	wire 					 					    mem_in_ready_to_receive,
input 	wire 										    mem_in_data_ready,

//Output to memory interface
output 	wire 	[LEN_ADDR-1: 0] 					    mem_out_addr,
output 	wire 	[LEN_DATA_RHS-1: 0] 				    mem_out_data,
output  wire 										    out_wrt_enbl_mem,
output  reg 										    out_receive_enbl_mem,
output  wire 										    out_available_mem,
output  wire    [NUM_DMA-1:0]                            mem_out_id,
output 	reg 										    out_burst_done,

//Output to forwarding unit
output 	reg 	[LEN_PROCESSOR_NO-1: 0] 			    FU_out_processor_id,
output 	reg 	[LEN_DATA_LHS-1: 0] 				    FU_out_data,
output 	reg 	[LEN_ADDR-1: 0] 					    FU_out_addr,
output 	reg 										    FU_out_data_ready_for_fu,
output  reg    [PACKT_LEN-1 : 0]                        FU_out_tx_count,
output 	reg 	[LEN_SLOT_ID-1: 0] 			            FU_out_slot_id,

//Output to Command Decoder
output 	reg 										    ready_to_receive_CD

    );


// DMA Ctrl
wire 	[NUM_DMA-1 : 0]						                        dma_ctrl_ready_to_receive;
wire 	[NUM_DMA-1 : 0]						                        dma_ctrl_occupied;
wire    [NUM_DMA-1 : 0] [LEN_SLOT_ID+LEN_PROCESSOR_NO-1: 0]         dma_occupy_id;

wire 	[LEN_ADDR-1: 0] 					out_addr_dma;
wire 	[LEN_PROCESSOR_NO-1: 0] 			out_processor_id_dma;
wire    [LEN_SLOT_ID-1 : 0]                 out_slot_id_dma;
wire    [PACKT_LEN-1 : 0]                   out_pkt_size_dma;
wire 	[LEN_DATA_LHS-1: 0] 				out_data_dma;
wire 					 					out_wr_enbl_dma;
wire 	[NUM_DMA-1 : 0]	 					out_addr_dma_en;
wire 	[NUM_DMA-1 : 0]	 					out_data_dma_en;
wire    [NUM_DMA-1 : 0][NUM_DMA_BITS:0]     dma_no;
wire    [NUM_DMA-1 : 0][NUM_DMA-1:0]        dma_no_onehot;

reg    [NUM_DMA-1:0]                       matched_dma_onehot;
reg                                        matched_dma_avl;

reg    [NUM_DMA_BITS:0]                    empty_dma_no;
reg                                        empty_dma_avl;
reg    [NUM_DMA-1:0]                       empty_dma_onehot;

integer k,l;


// Register for next pipeline statage to work
reg 	[LEN_ADDR-1: 0] 					pip0_in_CD_addr;
reg 	[LEN_PROCESSOR_NO-1: 0] 			pip0_in_CD_processor_id;
reg     [LEN_SLOT_ID-1 : 0]                 pip0_CD_in_slot_id;
reg     [PACKT_LEN-1 : 0]                   pip0_CD_in_pkt_size;
reg 	[LEN_DATA_LHS-1: 0] 				pip0_in_CD_data;
reg 										pip0_in_CD_wrt;
reg 										pip0_in_CD_addr_en;
reg                                         pip0_in_CD_addr_ctrl_en;
reg 										pip0_in_CD_data_en;
// reg 										pip0_in_CD_receive_enbl;
reg                                         pip0_in_CD_dma_start;

reg    [NUM_DMA:0]                         pip0_matched_dma_onehot;
reg                                        pip0_matched_dma_avl;

reg    [NUM_DMA_BITS:0]                    pip0_empty_dma_no;
reg    [NUM_DMA_BITS:0]                    pip0_empty_dma_nop1;
reg                                        pip0_empty_dma_avl;
reg    [NUM_DMA:0]                         pip0_empty_dma_onehot;
wire    [NUM_DMA:0]                        pip0_empty_dma_onehotp1;

reg    [NUM_DMA:0]                         pip0_selected_dma;


wire    [NUM_DMA-1:0]                      mem_in_data_ready_combine;

// memory_out
//Output to memory interface
wire 	[NUM_DMA-1:0][LEN_ADDR-1: 0] 					    mem_out_addr_combine;
wire 	[NUM_DMA-1:0][LEN_DATA_RHS-1: 0] 				    mem_out_data_combine;
wire 	[NUM_DMA-1:0]									    out_wrt_enbl_mem_combine;
wire 	[NUM_DMA-1:0]									    out_receive_enbl_mem_combine;
wire 	[NUM_DMA-1:0]									    out_available_mem_combine;
wire 	[NUM_DMA-1:0]									    out_burst_done_combine;

//Output to forwarding unit
wire 	[NUM_DMA-1:0][LEN_PROCESSOR_NO-1: 0] 			    FU_out_processor_id_combine;
wire 	[NUM_DMA-1:0][LEN_DATA_LHS-1: 0] 				    FU_out_data_combine;
wire 	[NUM_DMA-1:0][LEN_ADDR-1: 0] 					    FU_out_addr_combine;
wire 	[NUM_DMA-1:0]									    FU_out_data_ready_for_fu_combine;
wire    [NUM_DMA-1:0][PACKT_LEN-1 : 0]                      FU_out_tx_count_combine;
wire 	[NUM_DMA-1:0][LEN_SLOT_ID-1: 0] 			        FU_out_slot_id_combine;
reg    [NUM_DMA-1:0]                                        FU_dma_no_onehot;

wire 	[NUM_DMA-1:0]									    dma_process_done;
reg 	[NUM_DMA-1:0]									    dma_mem_process_select;


// input FU
wire 	[NUM_DMA-1:0]						                FU_ready_to_receive_data_combine;

wire 	[NUM_DMA-1:0]                                       mem_in_ready_to_receive_combine;

wire                                                        process_ready_for_memory;

wire                                                        inst_dma_id_n_addr_empty;
wire                                                        inst_dma_id_n_addr_full;

// Handling Input data from CD

assign pip0_empty_dma_onehotp1 = {empty_dma_onehot[NUM_DMA-2:0],1'b0};

always @(*) begin
    matched_dma_avl     <= 0;
    matched_dma_onehot  <= 0;
    for(k=NUM_DMA-1; k >= 0; k = k-1) begin
        if ((dma_ctrl_occupied[k] == 1'b1) & ((dma_occupy_id[k] == {in_CD_processor_id,CD_in_slot_id}))) begin
                matched_dma_avl         <= 1;
                matched_dma_onehot      <= dma_no_onehot[k];
        end
    end
end

always @(*) begin
    empty_dma_no        <= 0;
    empty_dma_avl       <= 0;
    empty_dma_onehot    <= 0;

    for (l=NUM_DMA-1; l >= 0; l = l-1) begin
        if (~(dma_ctrl_occupied[l])) begin
            empty_dma_avl       <= 1;
            empty_dma_no        <= dma_no;
            empty_dma_onehot    <= dma_no_onehot[l];
        end
    end
end

always @(posedge clk) begin
    if (~rst) begin
        pip0_in_CD_addr 			<= 0;
        pip0_in_CD_processor_id 	<= 0;
        pip0_CD_in_slot_id 			<= 0;
        pip0_CD_in_pkt_size 		<= 0;
        pip0_in_CD_data 			<= 0;
        pip0_in_CD_wrt 				<= 0;
        pip0_in_CD_addr_en 			<= 0;
        pip0_in_CD_data_en 			<= 0;
        pip0_in_CD_dma_start 		<= 0;
        pip0_matched_dma_onehot 	<= 0;
        pip0_matched_dma_avl 		<= 0;
        pip0_empty_dma_no 			<= 0;
        pip0_empty_dma_avl 			<= 0;
        pip0_empty_dma_onehot 		<= 0;
        pip0_selected_dma           <= 0;
        pip0_in_CD_addr_ctrl_en    <= 0;
    end else begin
        pip0_in_CD_addr 			<= in_CD_addr;
        pip0_in_CD_processor_id 	<= in_CD_processor_id;
        pip0_CD_in_slot_id 			<= CD_in_slot_id;
        pip0_CD_in_pkt_size 		<= CD_in_pkt_size;
        pip0_in_CD_data 			<= in_CD_data;
        pip0_in_CD_wrt 				<= in_CD_wrt;
        pip0_in_CD_addr_en 			<= in_CD_addr_en;
        pip0_in_CD_addr_ctrl_en     <= in_CD_addr_ctrl_en;
        pip0_in_CD_data_en 			<= in_CD_data_en;
        pip0_in_CD_dma_start 		<= in_CD_dma_start;
        pip0_matched_dma_onehot 	<= matched_dma_onehot;
        pip0_matched_dma_avl 		<= matched_dma_avl;
        pip0_empty_dma_no 			<= empty_dma_no;
        pip0_empty_dma_avl 			<= empty_dma_avl;

        if(in_CD_addr_ctrl_en) begin
            if(matched_dma_avl) begin
                pip0_selected_dma <= matched_dma_onehot;
            end else if(empty_dma_avl) begin
                if(pip0_empty_dma_avl & (((pip0_in_CD_addr_ctrl_en == 1'b1)|(pip0_in_CD_addr_en == 1'b1)) & ({pip0_in_CD_processor_id,pip0_CD_in_slot_id} != {in_CD_processor_id,CD_in_slot_id}))) begin
                    pip0_selected_dma 		<= pip0_empty_dma_onehotp1;
                end else begin
                    pip0_selected_dma 		<= empty_dma_onehot;
                end
            end
        end

    end
end

always @(*) begin
    ready_to_receive_CD             <= 0;
    if (|(dma_ctrl_ready_to_receive)) begin
            ready_to_receive_CD     <= 1;
    end
end


assign out_addr_dma_en = {(NUM_DMA){pip0_in_CD_addr_en}} & pip0_selected_dma;
assign out_data_dma_en = {(NUM_DMA){pip0_in_CD_data_en}} & pip0_selected_dma;

// Input from memory interface
assign mem_in_data_ready_combine = {(NUM_DMA){mem_in_data_ready}} & mem_in_id;

always@(posedge clk) begin
    if(~rst) begin
        dma_mem_process_select <= {{(NUM_DMA-1){1'b0}},1'b1};
    end else begin
        if(~(|(dma_ctrl_occupied))) begin
            dma_mem_process_select <= {{(NUM_DMA-1){1'b0}},1'b1};
        end
        else if((|((~dma_ctrl_occupied) & dma_mem_process_select))) begin
            dma_mem_process_select <= {dma_mem_process_select[NUM_DMA-2:0],dma_mem_process_select[NUM_DMA-1]};
        end
        else if((|(dma_process_done & dma_mem_process_select)) == 1'b1) begin
            dma_mem_process_select <= {dma_mem_process_select[NUM_DMA-2:0],dma_mem_process_select[NUM_DMA-1]};
        end
    end 
end

integer m,n;


assign process_ready_for_memory = (|(dma_mem_process_select & dma_mem_process_select));
//assign process_ready_for_memory = (|(dma_mem_process_select & dma_mem_process_select));

//always @(*) begin
//    out_receive_enbl_mem        <= 0;
//        if ((process_ready_for_memory == 1'b1)) begin
//                out_receive_enbl_mem    <= 1;
//        end
//end


reg 	[LEN_ADDR-1: 0] 					    reg_mem_out_addr;
reg 	[LEN_DATA_RHS-1: 0] 				    reg_mem_out_data;
reg 										    reg_out_wrt_enbl_mem;
reg 										    reg_out_receive_enbl_mem;
reg 										    reg_out_available_mem;
reg    [NUM_DMA-1:0]                            reg_mem_out_id;
reg 										    reg_out_burst_done;


always@(*) begin
    out_receive_enbl_mem    <=	reg_out_receive_enbl_mem;
    out_burst_done          <= 	reg_out_burst_done;
end

dma_top_addr_n_dma_id inst_dma_id_n_addr (
    .clk(clk),
    .din({reg_mem_out_addr,reg_mem_out_id,reg_mem_out_data,reg_out_wrt_enbl_mem}),
    .wr_en(reg_out_available_mem),
    .rd_en(mem_in_ready_to_receive),
    .dout({mem_out_addr,mem_out_id,mem_out_data,out_wrt_enbl_mem}),
    .full(inst_dma_id_n_addr_full),
    .empty(inst_dma_id_n_addr_empty)
);

assign out_available_mem = (~inst_dma_id_n_addr_empty);

//dma_top_data_512 inst_dma_data (
//    .clk(clk),
//    .din(reg_mem_out_data),
//    .wr_en(reg_out_wrt_enbl_mem),
//    .rd_en(),
//    .dout(),
//    .full(),
//    .empty()
//);



always @(*) begin
    reg_mem_out_addr                        <= {(LEN_ADDR){1'bx}};
    reg_mem_out_data			            <= {(LEN_DATA_RHS){1'bx}};
    reg_out_wrt_enbl_mem		            <= 0;
    reg_out_receive_enbl_mem	            <= 0;
    reg_out_available_mem		            <= 0;
    reg_out_burst_done 			            <= 0;
    reg_mem_out_id                          <= {(NUM_DMA){1'bx}};


    for (n=(NUM_DMA-1); n>=0; n=n-1) begin
        if(dma_mem_process_select[n] == 1'b1) begin
            reg_mem_out_addr 				        <= mem_out_addr_combine[n];
            reg_mem_out_data 				        <= mem_out_data_combine[n];
            reg_out_wrt_enbl_mem 			        <= out_wrt_enbl_mem_combine[n];
            reg_out_receive_enbl_mem 		        <= out_receive_enbl_mem_combine[n];
            reg_out_available_mem 			        <= out_available_mem_combine[n];
            reg_out_burst_done 				        <= out_burst_done_combine[n];
            reg_mem_out_id                          <= dma_no_onehot[n];
 
        end
    end
end

assign mem_in_ready_to_receive_combine = ({(NUM_DMA){(~inst_dma_id_n_addr_full)}}) & reg_mem_out_id;

always @(*) begin
    FU_out_processor_id 			<= 0;
    FU_out_data 					<= 0;
    FU_out_addr 					<= 0;
    FU_out_data_ready_for_fu 		<= 0;
    FU_out_tx_count 				<= 0;
    FU_out_slot_id 					<= 0;
    FU_dma_no_onehot                <= 0;

    for (n=(NUM_DMA-1); n>=0; n=n-1) begin
        if(FU_out_data_ready_for_fu_combine[n]) begin
            FU_out_processor_id 		<= FU_out_processor_id_combine[n];
            FU_out_data 				<= FU_out_data_combine[n];
            FU_out_addr 				<= FU_out_addr_combine[n];
            FU_out_data_ready_for_fu 	<= FU_out_data_ready_for_fu_combine[n];
            FU_out_tx_count 			<= FU_out_tx_count_combine[n];
            FU_out_slot_id 				<= FU_out_slot_id_combine[n];
            FU_dma_no_onehot            <= dma_no_onehot[n];
        end
    end
end


assign FU_ready_to_receive_data_combine = FU_dma_no_onehot & ({(NUM_DMA){FU_ready_to_receive_data}});

// Modules

genvar i;

generate

for(i=0; i < NUM_DMA; i=i+1) begin: dma_ins

    DMA_Ctrl 
    #(
        .LEN_ADDR         (LEN_ADDR         ),
        .LEN_DATA_LHS     (LEN_DATA_LHS     ),
        .LEN_PROCESSOR_NO (LEN_PROCESSOR_NO ),
        .LEN_SLOT_ID      (LEN_SLOT_ID      ),
        .LEN_DATA_RHS     (LEN_DATA_RHS     ),
        .PACKT_LEN        (PACKT_LEN),
        .NUM_DMA_BITS     (NUM_DMA_BITS),
        .NUM_DMA          (NUM_DMA),
        .DMA_NO           (i),
        .DMA_NO_ONEHOT    ((1 << i))
    )
    u_DMA_Ctrl(
        .clk                      (clk),
        .rst                      (rst),
        .in_CD_addr               (pip0_in_CD_addr),
        .in_CD_processor_id       (pip0_in_CD_processor_id),
        .CD_in_slot_id            (pip0_CD_in_slot_id),
        .CD_in_pkt_size           (pip0_CD_in_pkt_size),
        .in_CD_data               (pip0_in_CD_data),
        .in_CD_wrt                (pip0_in_CD_wrt),
        .in_CD_addr_en            (out_addr_dma_en[i]),
        .in_CD_data_en            (out_data_dma_en[i]),
        .FU_ready_to_receive_data (FU_ready_to_receive_data_combine[i]),
        .mem_in_data              (mem_in_data),
        .mem_in_ready_to_receive  (mem_in_ready_to_receive_combine[i]), // todo
        .mem_in_data_ready        (mem_in_data_ready_combine[i]),
        .mem_out_addr             (mem_out_addr_combine[i]),
        .mem_out_data             (mem_out_data_combine[i]),
        .out_wrt_enbl_mem         (out_wrt_enbl_mem_combine[i]),
        .out_receive_enbl_mem     (out_receive_enbl_mem_combine[i]),
        .out_available_mem        (out_available_mem_combine[i]),
        .out_burst_done           (out_burst_done_combine[i]),
        .process_done             (dma_process_done[i]),
        .FU_out_processor_id      (FU_out_processor_id_combine[i]),
        .FU_out_data              (FU_out_data_combine[i]),
        .FU_out_addr              (FU_out_addr_combine[i]),
        .FU_out_data_ready_for_fu (FU_out_data_ready_for_fu_combine[i]),
        .FU_out_tx_count          (FU_out_tx_count_combine[i]),
        .FU_out_slot_id           (FU_out_slot_id_combine[i]),
        .ready_to_receive_CD      (dma_ctrl_ready_to_receive[i]),
        .dma_occupied             (dma_ctrl_occupied[i]),
        .dma_occupy_id            (dma_occupy_id[i]),
        .dma_no                   (dma_no[i]),
        .dma_no_onehot            (dma_no_onehot[i])
    );

end

endgenerate

endmodule
