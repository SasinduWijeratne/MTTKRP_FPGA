`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: pgroup @ usc
// Engineer: Sasindu Wijeratne
// 
// Create Date: 07/28/2020 01:31:14 AM
// Design Name: 
// Module Name: issue_to_DDR
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


module issue_to_DDR_DMA #(
parameter 	LEN_ADDR 			=	 32,
parameter 	LEN_DATA_LHS 		= 	 512,
parameter 	LEN_DATA_RHS 		= 	 512
	)(
input	wire										clk,
input   wire                                        mem_clk,
input 	wire 										rst,

//input from scheduler
input  wire 	[LEN_ADDR-1: 0] 					in_sch_mem_out_addr,
input  wire 	[LEN_DATA_LHS-1: 0] 				in_sch_mem_out_data,
input  wire 										in_sch_out_wrt_enbl_mem,
input  wire 										in_sch_out_receive_enbl_mem,
input  wire 										in_sch_out_available_mem,
input  wire 										in_sch_out_burst_done,

//Input from memory interface
input 	wire 	[LEN_DATA_RHS-1: 0] 				mem_in_data,
input 	wire 					 					mem_in_ready_to_receive, // RHS is accepting data
input 	wire 										mem_in_data_ready, // RHS data available


//output to scheduler
output 	reg 	[LEN_DATA_LHS-1: 0] 				out_sch_mem_in_data,
output 	reg 					 					out_sch_mem_in_ready_to_receive = 0, // RHS is accepting data
output 	wire 										out_sch_mem_in_data_ready, // RHS data available


//Output to memory interface
output 	reg 	[LEN_ADDR-1: 0] 					mem_out_addr,
output 	reg 	[LEN_DATA_RHS-1: 0] 				mem_out_data,
output  reg 										out_wrt_enbl_mem,
output  reg 										out_receive_enbl_mem,
output  reg 										out_available_mem,
output  wire    [(LEN_DATA_RHS/8)-1 : 0] 			app_wdf_mask,
output 	reg 										out_burst_done

    );

localparam 					STATE_BITS 				= 4;

localparam 					STATE_SCH_READ			= 3;

localparam 					STATE_IDLE 				= 0;
localparam 					STATE_SEND 				= 1;
localparam 					STATE_RECEIVE			= 2;

localparam 					STATE_RECEIVE_SCH		= 1;
localparam 					STATE_RECEIVE_SCH_DONE	= 2;

localparam 					SEND_STATE_IDLE 		= 0;
localparam 					SEND_STATE_READ 		= 1;
localparam 					SEND_STATE_WRITE 		= 2;

localparam 					PKT_COUNTER_LIM 		= 8;

localparam                  DEPTH_MEM2FU_FIFO       = 16;
localparam                  DEPTH_MEM2FU_FIFO__2    = (DEPTH_MEM2FU_FIFO -2);


reg 	[STATE_BITS-1: 0] 							state = 0;
//reg 	[STATE_BITS-1: 0] 							state_mem_issue = 0;
reg 	[$clog2(PKT_COUNTER_LIM)+1 : 0] 			burst_counter;
//reg 	[$clog2(PKT_COUNTER_LIM)+1 : 0] 			to_sch_burst_counter = 0;

reg  [LEN_DATA_RHS-1 : 0]					 		in_from_sch_width_255_data_fifo;
wire  [LEN_DATA_RHS-1 : 0]					 		out_from_sch_width_255_data_fifo;
reg 												wr_en_data_from_scheduler;
reg 												rd_en_data_from_scheduler;
wire 												sch_fifo_full;
wire 												sch_fifo_empty;

reg  [LEN_DATA_RHS-1 : 0]					 		out_to_sch_width_255_data_fifo;
wire 												to_sch_fifo_full;
wire 												to_sch_fifo_empty;
reg 												wr_en_data_to_scheduler;

wire [LEN_ADDR-1: 0] 								out_sch_mem_out_addr;
wire 												out_sch_mem_out_wr_en;
reg 												wr_en_fifo_addr;
reg 												rd_en_fifo_addr;
wire 												fifo_addr_full;
wire 												fifo_addr_empty;
wire 												fifo_wr_en_full;
wire 												fifo_wr_en_empty;

wire 												wire_ready_to_receive;
reg [STATE_BITS-1:0]							    cumilate_data_fr_sch;

reg [1:0] 											cumilate_data_to_sch;

reg [LEN_DATA_RHS-LEN_DATA_LHS-1 : 0]				reg_in_to_sch_width_255_data_fifo;

reg [LEN_ADDR-1: 0] 					reg_in_sch_mem_out_addr;
reg                                     reg_in_sch_out_wrt_enbl_mem;
reg                                     inter_reg_in_sch_out_wrt_enbl_mem;

wire 									out_sch_mem_in_data_ready0;

reg [$clog2(DEPTH_MEM2FU_FIFO)+1 : 0]       count_wr_sent_rec_mem;
reg [2:0]                                   burst_count; // burst = 8 3 bit
reg                                         readt_to_send_wr_mem_inter;

assign app_wdf_mask = 0;

assign wire_ready_to_receive = (~sch_fifo_full) & (~fifo_addr_full);

always@(*) begin: mem_issue_SM
	if(~rst) begin

		out_wrt_enbl_mem 					<= 0;
		out_burst_done                      <= 0;
		out_receive_enbl_mem 				<= 0;
		out_available_mem 					<= 0;

		rd_en_data_from_scheduler 			<= 0;
		rd_en_fifo_addr 			        <= 0;
		wr_en_data_to_scheduler 			<= 0;
		mem_out_addr                        <= 0;
		mem_out_data 				        <= 0;
		out_to_sch_width_255_data_fifo 	    <= 0;

	end else begin

		out_burst_done                      <= 0;
		out_receive_enbl_mem 				<= 0;
		out_available_mem 					<= 0;
		rd_en_fifo_addr 			        <= 0;
		rd_en_data_from_scheduler 			<= 0;
		wr_en_data_to_scheduler 			<= 0;
		mem_out_addr 				        <= out_sch_mem_out_addr;
		out_wrt_enbl_mem 			        <= out_sch_mem_out_wr_en;
		mem_out_data 				        <= out_from_sch_width_255_data_fifo;
		out_to_sch_width_255_data_fifo 	    <= mem_in_data;
		
		if(mem_in_ready_to_receive) begin
				
				if((~fifo_addr_empty)) begin
				
					rd_en_fifo_addr 			<= 1;
					out_receive_enbl_mem 		<= 0;
					out_available_mem 			<= 1;

					if(out_sch_mem_out_wr_en) begin
						out_burst_done             <= 1;
						rd_en_data_from_scheduler 	<= 1; 
					end
				end
		end
		if (mem_in_data_ready) begin // (mem_in_ready_to_receive & mem_in_data_ready)
			
				if(~to_sch_fifo_full) begin
					wr_en_data_to_scheduler			<= mem_in_data_ready;
					out_receive_enbl_mem 	     	<= 1;
				end
		end
	 end
end

always@(posedge clk) begin: save_fr_SCH_SEQ
	if(~rst) begin
		in_from_sch_width_255_data_fifo 							<= {(LEN_DATA_RHS){1'bx}};
		burst_counter 												<= 0;
		wr_en_fifo_addr 											<= 0;
		wr_en_data_from_scheduler 									<= 0;
		reg_in_sch_out_wrt_enbl_mem                                 <= 0;
		inter_reg_in_sch_out_wrt_enbl_mem                           <= 0;
		reg_in_sch_mem_out_addr                                     <= {(LEN_ADDR){1'bx}};

	end else begin
		wr_en_fifo_addr 											<= 0;
		wr_en_data_from_scheduler 									<= 0;
		reg_in_sch_out_wrt_enbl_mem                                 <= 0;
		in_from_sch_width_255_data_fifo                      	    <= in_sch_mem_out_data;
		reg_in_sch_mem_out_addr                                     <= in_sch_mem_out_addr;

		if((in_sch_out_available_mem) & wire_ready_to_receive) begin
		      if(in_sch_out_wrt_enbl_mem) begin
				wr_en_fifo_addr 										<= 1;
			    burst_counter 											<= 0;
				reg_in_sch_out_wrt_enbl_mem                         	<= 1;
				wr_en_data_from_scheduler 								<= 1;
			    
			  end else begin
			     if(readt_to_send_wr_mem_inter) begin
		              wr_en_fifo_addr                                         <= 1;
		              reg_in_sch_out_wrt_enbl_mem                             <= 0;
		         end
			  end

		end //else if((cumilate_data_fr_sch == STATE_RECEIVE_SCH)& wire_ready_to_receive) begin
		// 	     in_from_sch_width_255_data_fifo 						<= (in_from_sch_width_255_data_fifo << LEN_DATA_LHS) + in_sch_mem_out_data;
		// 	     burst_counter 											<= burst_counter + 1'b1;
			
		// 	     if(burst_counter == PKT_COUNTER_LIM-1) begin
		// 		    cumilate_data_fr_sch 								<= STATE_IDLE;
		// 		    wr_en_fifo_addr 									<= 1;
        //             reg_in_sch_out_wrt_enbl_mem                         <= 1;
        //             wr_en_data_from_scheduler 							<= 1;
		// 	     end
		// end

	end

end

always@(*) begin: save_fr_SCH
	if(~rst) begin
		out_sch_mem_in_ready_to_receive 							<= 0;
	end else begin
		out_sch_mem_in_ready_to_receive 							<= wire_ready_to_receive;

		if(wire_ready_to_receive) begin
		      if(~in_sch_out_wrt_enbl_mem) begin
			    if(~readt_to_send_wr_mem_inter) begin
			     out_sch_mem_in_ready_to_receive                          <= 0;
			    end
			  end
		 end // else if(~(cumilate_data_fr_sch == STATE_RECEIVE_SCH)) begin
    	//    if(~readt_to_send_wr_mem_inter) begin
		//       out_sch_mem_in_ready_to_receive                          <= 0;
		//    end
		// end
	end

end

//always@(posedge clk) begin
//    if(in_sch_out_receive_enbl_mem) begin
//        burst_count <= burst_count + 1'b1;
//    end
//end

always@(posedge clk) begin: WR_CNSTR
    if (~rst) begin 
        count_wr_sent_rec_mem           <= 0;
    end
    else begin
        
       if((wr_en_fifo_addr & (reg_in_sch_out_wrt_enbl_mem == 0) & (~in_sch_out_receive_enbl_mem))) begin
                count_wr_sent_rec_mem       <= count_wr_sent_rec_mem + 1;
        end
        else if (in_sch_out_receive_enbl_mem & (~out_sch_mem_in_data_ready0)) begin
            if(count_wr_sent_rec_mem != 0) begin
                count_wr_sent_rec_mem       <= count_wr_sent_rec_mem - 1;
            end
        end
        
    end
end

always@(posedge clk) begin: WR_CNSTR2
    if (~rst) begin 
        readt_to_send_wr_mem_inter      <= 0;
    end else begin
        if(count_wr_sent_rec_mem < DEPTH_MEM2FU_FIFO__2) begin
            readt_to_send_wr_mem_inter          <= 1;
        end else begin
            readt_to_send_wr_mem_inter          <= 0;
        end
    end
end

Interface_with_memory data_from_scheduler(
    .wr_clk(clk),
    .rd_clk(mem_clk),
    .din(in_from_sch_width_255_data_fifo),
    .wr_en(wr_en_data_from_scheduler),
    .rd_en(rd_en_data_from_scheduler),
    .dout(out_from_sch_width_255_data_fifo),
    .full(),
    .almost_full(sch_fifo_full),
    .empty(sch_fifo_empty)
  );
  									
mem_address0 inst_LHS_input_fifo_addr(
                                        .wr_clk(clk),
                                        .rd_clk(mem_clk),
    									.din(reg_in_sch_mem_out_addr),
    									.wr_en(wr_en_fifo_addr),
    									.rd_en(rd_en_fifo_addr),
    									.dout(out_sch_mem_out_addr),
    									.full(),
    									.almost_full(fifo_addr_full),
    									.empty(fifo_addr_empty)
                                    );

rd_wr_en_fifo rd_wr_en_fifo_1 (
    .wr_clk(clk),
    .rd_clk(mem_clk),
    .din(reg_in_sch_out_wrt_enbl_mem),
    .wr_en(wr_en_fifo_addr),
    .rd_en(rd_en_fifo_addr),
    .dout(out_sch_mem_out_wr_en),
    .full(fifo_wr_en_full),
    .empty(fifo_wr_en_empty)
  );

 // Change to 512 in 512 out
mem2fu_fifo_0 takefrmemory_sv2fu (
  .wr_clk(mem_clk),
  .rd_clk(clk),
  .din(out_to_sch_width_255_data_fifo),
  .wr_en(wr_en_data_to_scheduler),
  .rd_en(in_sch_out_receive_enbl_mem),
  .dout(out_sch_mem_in_data),
  .full(to_sch_fifo_full),
  .empty(out_sch_mem_in_data_ready0)
);

assign out_sch_mem_in_data_ready = ~out_sch_mem_in_data_ready0;

endmodule
