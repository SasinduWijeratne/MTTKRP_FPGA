`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: pgroup @ usc
// Engineer: Sasindu Wijeratne
// 
// Create Date: 02/16/2021 10:45:13 PM
// Design Name: 
// Module Name: DMA_Ctrl
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

module DMA_Ctrl #(
parameter 	LEN_ADDR 			=	 35,
parameter 	LEN_DATA_LHS 		= 	 64,
parameter 	LEN_PROCESSOR_NO 	= 	  7,
parameter   LEN_SLOT_ID         =     7,
parameter 	LEN_DATA_RHS 		= 	512,
parameter   PACKT_LEN           =    13,
parameter   NUM_DMA_BITS        =     5,
parameter   NUM_DMA             =     4,
parameter   DMA_NO              =     0,
parameter   DMA_NO_ONEHOT       =     0
)(

input	wire										    clk,
input 	wire 										    rst,

//input from Command Decoder
input  wire 	[LEN_ADDR-1: 0] 					    in_CD_addr,
input  wire 	[LEN_PROCESSOR_NO-1: 0] 			    in_CD_processor_id,
input  wire     [LEN_SLOT_ID-1 : 0]                     CD_in_slot_id,
input  wire     [PACKT_LEN-1 : 0]                       CD_in_pkt_size,
input  wire 	[LEN_DATA_LHS-1: 0] 				    in_CD_data,
input  wire 										    in_CD_wrt,
input  wire 										    in_CD_addr_en,
input  wire 										    in_CD_data_en,
// input  wire 										    in_CD_receive_enbl,

//Input from forwarding unit
// input 	wire 										FU_ready_to_receive,
input 	wire 										    FU_ready_to_receive_data,

//Input from memory interface
input 	wire 	[LEN_DATA_RHS-1: 0] 				    mem_in_data,
input 	wire 					 					    mem_in_ready_to_receive,
input 	wire 										    mem_in_data_ready,

//Output to memory interface
output 	reg 	[LEN_ADDR-1: 0] 					    mem_out_addr,
output 	reg 	[LEN_DATA_RHS-1: 0] 				    mem_out_data,
output  reg 										    out_wrt_enbl_mem,
output  reg 										    out_receive_enbl_mem,
output  reg 										    out_available_mem,
output 	wire 										    out_burst_done,

output  reg                                             process_done, 

//Output to forwarding unit
output 	wire 	[LEN_PROCESSOR_NO-1: 0] 			    FU_out_processor_id,
output 	wire 	[LEN_DATA_LHS-1: 0] 				    FU_out_data,
output 	wire 	[LEN_ADDR-1: 0] 					    FU_out_addr,
output 	wire 										    FU_out_data_ready_for_fu,
output  wire    [PACKT_LEN-1 : 0]                       FU_out_tx_count,
output 	wire 	[LEN_SLOT_ID-1: 0] 			            FU_out_slot_id,

//Output to Command Decoder
output 	reg 										    ready_to_receive_CD,
output  wire                                             dma_occupied, // todo
output  wire      [LEN_SLOT_ID+LEN_PROCESSOR_NO-1: 0]   dma_occupy_id, // todo  {in_CD_processor_id,CD_in_slot_id}  
output  wire     [NUM_DMA_BITS:0]                       dma_no,
output  wire     [NUM_DMA-1:0]                          dma_no_onehot

    );

localparam          LEN_READ_COUNT                         = 7;

localparam          STATE_INIT                             = 0,
                    STATE_IDLE                             = 1,
                    STATE_READ                             = 2,
                    STATE_WRITE                            = 3,
                    STATE_DONE                             = 4;

localparam          NUM_STATE                              = 5;

reg [$clog2(NUM_STATE)+1:0]                                state = STATE_INIT;




wire [LEN_DATA_LHS-1: 0] 				            cd_to_mem_fifo_data_in;
wire [LEN_DATA_RHS-1: 0] 				            cd_to_mem_fifo_data_out;
reg                                                 cd_to_mem_converter_fifo_rd_en;
wire                                                cd_to_mem_converter_fifo_wr_en;
wire                                                cd_to_mem_converter_fifo_empty;
wire                                                cd_to_mem_converter_fifo_full;


wire [LEN_DATA_LHS-1: 0] 				            mem_to_cd_fifo_data_out;
reg  [LEN_DATA_RHS-1: 0] 				            mem_to_cd_fifo_data_in;
wire                                                mem_to_cd_fifo_rd_en;
reg                                                 mem_to_cd_fifo_wr_en;
wire                                                mem_to_cd_fifo_empty;
wire                                                mem_to_cd_fifo_full;



wire                                                dma_data_fifo_full;
wire                                                dma_data_fifo_empty;
reg  [LEN_DATA_RHS-1:0]                             dma_data_fifo_in;
wire [LEN_DATA_RHS-1:0]                             dma_data_fifo_out;
reg                                                 dma_data_fifo_wr_en;
reg                                                 dma_data_fifo_rd_en;

wire                                                dma_addr_fifo_full;
wire                                                dma_addr_fifo_empty;
wire [LEN_ADDR-1:0]                                 dma_addr_fifo_in;
wire [LEN_ADDR-1:0]                                 dma_addr_fifo_out;
wire                                                dma_addr_fifo_wr_en;
reg                                                 dma_addr_fifo_rd_en = 0;


reg     [LEN_SLOT_ID-1 : 0]                         reg_slot_id;
reg 	[LEN_PROCESSOR_NO-1: 0] 			        reg_processor_id;
reg     [PACKT_LEN-1 : 0]                           reg_pkt_size;
reg                                                 reg_type_wr;   
reg 	[LEN_ADDR-1: 0] 					        reg_addr;

wire                                                rhs_data_ready;

reg     [LEN_READ_COUNT-1:0]                        reg_read_count;
reg     [LEN_ADDR-1:0]                              reg_send_count;
wire    [LEN_ADDR-1:0]                              wire_send_count_X8;

reg     [LEN_READ_COUNT-1:0]                        reg_flit_count;

reg 	[LEN_ADDR-1: 0] 					    in_CD_addr_reg;
reg 	[LEN_PROCESSOR_NO-1: 0] 			    in_CD_processor_id_reg;
reg     [LEN_SLOT_ID-1 : 0]                     CD_in_slot_id_reg;
reg     [PACKT_LEN-1 : 0]                       CD_in_pkt_size_reg;
reg 	[LEN_DATA_LHS-1: 0] 				    in_CD_data_reg;
reg 										    in_CD_wrt_reg;
reg 										    in_CD_addr_en_reg;
reg 										    in_CD_data_en_reg;

reg 	[LEN_DATA_RHS-1: 0] 				    reg_mem_in_data;
reg 					 					    reg_mem_in_ready_to_receive;
reg 										    reg_mem_in_data_ready;

reg                                             dma_occupied0; // todo

// DMA transaction must be less than the size of DMA_DATA_FIFO
// Logic behind writing to the DMA FIFO

// assign cd_to_mem_converter_fifo_rd_en = ((~dma_data_fifo_full) & (~cd_to_mem_converter_fifo_empty) & (in_CD_wrt));
// assign rhs_data_ready = ((~dma_data_fifo_full) & (~mem_in_data_ready) & (~in_CD_wrt));

// assign dma_data_fifo_wr_en = cd_to_mem_converter_fifo_rd_en | rhs_data_ready;
// assign dma_data_fifo_in = (rhs_data_ready) ? mem_in_data : cd_to_mem_fifo_data_out;


assign dma_addr_fifo_wr_en              = in_CD_addr_en_reg;
assign dma_addr_fifo_in                 = in_CD_addr_reg;

assign cd_to_mem_fifo_data_in           = in_CD_data_reg;
assign cd_to_mem_converter_fifo_wr_en   = in_CD_data_en_reg;
assign FU_out_processor_id              = reg_processor_id;
assign FU_out_addr                      = reg_addr;
assign FU_out_slot_id                   = reg_slot_id;
assign FU_out_data_ready_for_fu         = (~mem_to_cd_fifo_empty);
assign FU_out_data                      = mem_to_cd_fifo_data_out;

//assign ready_to_receive_CD              = (~dma_addr_fifo_full) & (~dma_data_fifo_full);
assign mem_to_cd_fifo_rd_en             = FU_ready_to_receive_data;

assign FU_out_tx_count                  = reg_pkt_size;

assign wire_send_count_X8               = (reg_send_count << 3);

assign dma_no                           = DMA_NO;
assign dma_no_onehot                    = DMA_NO_ONEHOT;
assign dma_occupy_id                    = {reg_processor_id,reg_slot_id};

// Logic behind reading from the DMA FIFO

// always @(posedge clk) begin
//     if(rst) begin
//         start_dma           <= 1'b0;
//         reg_slot_id         <= {(LEN_SLOT_ID){1'bx}};
//         reg_processor_id    <= {(LEN_PROCESSOR_NO){1'bx}};
//         reg_pkt_size        <= {(PACKT_LEN){1'bx}};
//         reg_type_wr         <= 1'bx;
//     end else begin
//         if(in_CD_dma_start) begin
//              start_dma           <= 1'b1;
//         end else if (state == STATE_DONE) begin
//             start_dma           <= 1'b0;
//         end

//         if(in_CD_addr_en) begin
//             reg_slot_id         <= CD_in_slot_id;
//             reg_processor_id    <= in_CD_processor_id; 
//             reg_pkt_size        <= CD_in_pkt_size;  
//             reg_type_wr         <= in_CD_wrt;   
//         end

//     end
// end


always@(posedge clk) begin
    in_CD_addr_reg              <= in_CD_addr;
    in_CD_processor_id_reg      <= in_CD_processor_id;
    CD_in_slot_id_reg           <= CD_in_slot_id;
    CD_in_pkt_size_reg          <= CD_in_pkt_size;
    in_CD_data_reg              <= in_CD_data;
    in_CD_wrt_reg               <= in_CD_wrt;
    in_CD_addr_en_reg           <= in_CD_addr_en;
    in_CD_data_en_reg           <= in_CD_data_en;
    
    reg_mem_in_data                 <= mem_in_data;
    reg_mem_in_data_ready           <= mem_in_data_ready;
end

assign dma_occupied = (in_CD_addr_en_reg == 1'b1) ? 1'b1 : dma_occupied0;


always@(*) begin
    reg_mem_in_ready_to_receive     <= mem_in_ready_to_receive;
end

always @(posedge clk) begin: prc_dma_state
    if(~rst) begin
        state                   <= STATE_INIT;
        reg_read_count          <= 0;
        reg_send_count          <= 0;
        reg_flit_count          <= 0;

        reg_slot_id         <= 0;
        reg_processor_id    <= 0;
        reg_pkt_size        <= 0;
        reg_type_wr         <= 0;
        reg_addr            <= 0;

        dma_occupied0        <= 0;
        
        process_done        <= 0;

    end else begin
        case(state)
            STATE_INIT: begin
                        dma_occupied0            <= 0;
                        process_done            <= 0;
                        if (in_CD_addr_en_reg) begin
                            dma_occupied0        <= 1;
                            reg_slot_id         <= CD_in_slot_id_reg;
                            reg_processor_id    <= in_CD_processor_id_reg; 
                            reg_pkt_size        <= CD_in_pkt_size_reg;  
                            reg_type_wr         <= in_CD_wrt_reg;
                            reg_addr            <= in_CD_addr_reg;
                            reg_flit_count      <= reg_flit_count + 1;

                            state               <= STATE_IDLE;
                        end
            end
            STATE_IDLE: begin
                    if(reg_type_wr == 0) begin
                        state           <= STATE_READ;
                        reg_read_count  <= 0;
                        reg_send_count  <= 0;
                    end else begin

                        if (in_CD_addr_en_reg) begin
                            reg_flit_count      <= reg_flit_count + 1;
                            if(reg_flit_count == (reg_pkt_size-1)) begin
                                state <= STATE_WRITE;    
                            end
                        end

                    end
            end
            STATE_READ: begin

                if (mem_in_ready_to_receive) begin
                    if(reg_send_count < (reg_pkt_size)) begin
                        reg_send_count          <= reg_send_count + 1;
                    end
                end

                if (~dma_data_fifo_full) begin
                    if(mem_in_data_ready) begin
                        reg_read_count      <= reg_read_count + 1'b1;
                    end
                end

                if(reg_read_count == (reg_pkt_size)) begin
                    state                   <= STATE_DONE;
                end
            end
            STATE_WRITE: begin

                        if((dma_data_fifo_empty) & dma_addr_fifo_empty) begin
                            state   <= STATE_DONE;
                        end
            end
            STATE_DONE: begin

                        reg_flit_count      <= 0;
                        process_done        <= 1;

                        if (reg_type_wr) begin
                            state               <= STATE_INIT;
                        end else begin

                            if(mem_to_cd_fifo_empty & dma_data_fifo_empty) begin
                                state               <= STATE_INIT;
                            end
                        end
            end
            default: begin
                        state <= STATE_INIT;
            end
        endcase

    end
end



always @(*) begin : proc_nsl
    if(~rst) begin

        dma_data_fifo_rd_en             <= 1'b0;
        dma_addr_fifo_rd_en             <= 1'b0;
        out_wrt_enbl_mem                <= 1'b0;
        out_available_mem               <= 1'b0;
        out_receive_enbl_mem            <= 1'b0;
        dma_data_fifo_wr_en             <= 1'b0;
        cd_to_mem_converter_fifo_rd_en  <= 1'b0;
        mem_to_cd_fifo_wr_en            <= 1'b0;

        dma_data_fifo_in                <= cd_to_mem_fifo_data_out;
        mem_out_addr                    <= dma_addr_fifo_out;
        mem_out_data                    <= dma_data_fifo_out;
        mem_to_cd_fifo_data_in          <= dma_data_fifo_out;
        
        ready_to_receive_CD             <= 1'b0;

    end else begin

        dma_data_fifo_rd_en             <= 1'b0;
        dma_addr_fifo_rd_en             <= 1'b0;
        out_wrt_enbl_mem                <= 1'b0;
        out_available_mem               <= 1'b0;
        out_receive_enbl_mem            <= 1'b0;
        dma_data_fifo_wr_en             <= 1'b0;
        cd_to_mem_converter_fifo_rd_en  <= 1'b0;
        mem_to_cd_fifo_wr_en            <= 1'b0;

        dma_data_fifo_in                <= cd_to_mem_fifo_data_out;
        mem_out_addr                    <= dma_addr_fifo_out;
        mem_out_data                    <= dma_data_fifo_out;
        mem_to_cd_fifo_data_in          <= dma_data_fifo_out;
        
        ready_to_receive_CD             <= 1'b0;

        case(state)
            STATE_INIT: begin
                ready_to_receive_CD             <= 1'b1;
            end
            STATE_IDLE: begin
                    if(reg_type_wr == 0) begin
                        ready_to_receive_CD             <= 1'b1;
                    end else begin
                            if(reg_flit_count < (reg_pkt_size-1) | ((reg_flit_count == (reg_pkt_size-1)) & ~in_CD_addr_en_reg)) begin
                                ready_to_receive_CD             <= 1'b1;
                            end
                    end
                    
                    if(state != STATE_READ) begin
                        if (~cd_to_mem_converter_fifo_empty & (~dma_data_fifo_full)) begin
                            dma_data_fifo_wr_en             <= 1'b1;
                            cd_to_mem_converter_fifo_rd_en  <= 1'b1;
                            dma_data_fifo_in                <= cd_to_mem_fifo_data_out;
                        end
                    end
            end
            
            STATE_READ: begin

                // if((~dma_data_fifo_empty) & (~mem_to_cd_fifo_full)) begin // We start sending done signal after we receive all the data. Gonna Comment
                //     dma_data_fifo_rd_en             <= 1'b1;
                //     mem_to_cd_fifo_wr_en            <= 1'b1;
                //     mem_to_cd_fifo_data_in          <= dma_data_fifo_out;
                // end

                // if (mem_in_ready_to_receive) begin
                //         if(~dma_addr_fifo_empty) begin
                //             dma_addr_fifo_rd_en     <= 1'b1;
                //             mem_out_addr            <= dma_addr_fifo_out;
                //             out_wrt_enbl_mem        <= 1'b0;
                //             out_available_mem       <= 1'b1;
                //         end
                // end

                if (mem_in_ready_to_receive) begin
                    if(reg_send_count < (reg_pkt_size)) begin
                        mem_out_addr            <= reg_addr + wire_send_count_X8;
                        out_wrt_enbl_mem        <= 1'b0;
                        out_available_mem       <= 1'b1;
                    end
                end
                if (~dma_data_fifo_full) begin
                    out_receive_enbl_mem <= 1'b1;
                    if(mem_in_data_ready) begin
                        dma_data_fifo_wr_en <= 1'b1;
                        dma_data_fifo_in    <= mem_in_data;
                    end
                end

                if(reg_read_count == (reg_pkt_size-1)) begin
                    dma_addr_fifo_rd_en     <= 1'b1;
                end
            end
            STATE_WRITE: begin
                        
                        if ((~cd_to_mem_converter_fifo_empty) & (~dma_data_fifo_full)) begin
                            dma_data_fifo_wr_en             <= 1'b1;
                            cd_to_mem_converter_fifo_rd_en  <= 1'b1;
                            dma_data_fifo_in                <= cd_to_mem_fifo_data_out;
                        end

                       if((~dma_data_fifo_empty) & (~dma_addr_fifo_empty)) begin

                            mem_out_addr            <= dma_addr_fifo_out;
                            mem_out_data            <= dma_data_fifo_out;
                            
                            if (mem_in_ready_to_receive) begin
                                dma_data_fifo_rd_en     <= 1'b1;
                                dma_addr_fifo_rd_en     <= 1'b1;
                                out_available_mem       <= 1'b1;
                                out_wrt_enbl_mem        <= 1'b1;
           
                            end
                        end
            end
            STATE_DONE: begin
                        ready_to_receive_CD             <= 1'b0;
                        if (~reg_type_wr) begin

                            if((~dma_data_fifo_empty) & (~mem_to_cd_fifo_full)) begin
                                dma_data_fifo_rd_en             <= 1'b1;
                                mem_to_cd_fifo_wr_en            <= 1'b1;
                            end
                        end
            end
        endcase

    end
end




/* Internal Buffers to store data/addresses */
WIDTH_CONVERTER_64_to_512 cd_to_mem_width_converter (
    .clk(clk),
    .din(cd_to_mem_fifo_data_in),
    .wr_en(cd_to_mem_converter_fifo_wr_en),
    .rd_en(cd_to_mem_converter_fifo_rd_en),
    .dout(cd_to_mem_fifo_data_out),
    .full(cd_to_mem_converter_fifo_full),
    .empty(cd_to_mem_converter_fifo_empty)
);
   
WIDTH_CONVERTER_512_to_64 mem_to_cd_width_converter (
    .clk(clk),
    .din(mem_to_cd_fifo_data_in),
    .wr_en(mem_to_cd_fifo_wr_en),
    .rd_en(mem_to_cd_fifo_rd_en),
    .dout(mem_to_cd_fifo_data_out),
    .full(mem_to_cd_fifo_full),
    .empty(mem_to_cd_fifo_empty)
);

DMA_DATA_FIFO dma_data (
    .clk(clk),
    .srst(~rst),
    .din(dma_data_fifo_in),
    .wr_en(dma_data_fifo_wr_en),
    .rd_en(dma_data_fifo_rd_en),
    .dout(dma_data_fifo_out),
    .full(dma_data_fifo_full),
    .empty(dma_data_fifo_empty)    
);

DMA_ADDR_FIFO dma_addr (
    .clk(clk),
    .srst(~rst),
    .din(dma_addr_fifo_in),
    .wr_en(dma_addr_fifo_wr_en),
    .rd_en(dma_addr_fifo_rd_en),
    .dout(dma_addr_fifo_out),
    .full(dma_addr_fifo_full),
    .empty(dma_addr_fifo_empty)    
);

endmodule