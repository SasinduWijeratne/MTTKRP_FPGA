`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/26/2021 02:52:16 PM
// Design Name: 
// Module Name: tensor_reordering_system
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


module tensor_reordering_system #(
    parameter TENSOR_WIDTH              = 128,
    parameter TENSOR_DIMENSIONS         = 3,
    parameter NUM_OF_SHARDS             = 1024,
    parameter TENSOR_DATA_WIDTH         = 32,
    parameter MODE_TENSOR_BLOCK_WIDTH   = 16,
    parameter DMA_DATA_WIDTH            = 512,
    parameter MODE_TENSOR_ADDR_WIDTH    = 16
)(
    input   wire                                                                                        clk,
    input   wire                                                                                        rst,
    input   wire                                                                                        input_tensor_element_en,
    input   wire [TENSOR_WIDTH-1 : 0]                                                                   input_tensor_element, // | BL_X | BL_Y | BL_Z | X | Y | Z | VAL |
    output  reg                                                                                         output_tensor_element_en,
    output  reg [DMA_DATA_WIDTH-1 : 0]                                                                  output_tensor_element // | BL_X | BL_Y | BL_Z | X | Y | Z | VAL |
    );

localparam NUM_OF_ELEMENTS_IN_LINE      = DMA_DATA_WIDTH/TENSOR_WIDTH;

genvar i;

reg [TENSOR_WIDTH-1 : 0]                                                                                tensor_element_blk_in;
reg [$clog2(NUM_OF_SHARDS)-1 : 0]                                                                       tensor_element_blk_addr_in;
reg [NUM_OF_ELEMENTS_IN_LINE-1: 0]                                                                      tensor_element_blk_in_en;
wire [NUM_OF_ELEMENTS_IN_LINE-1: 0][TENSOR_WIDTH-1 : 0]                                                 tensor_element_blk_out;
reg                                                                                                     tensor_element_blk_out_en;
reg [$clog2(NUM_OF_SHARDS)-1 : 0]                                                                       tensor_element_blk_addr_out;
reg  [NUM_OF_SHARDS-1 : 0][$clog2(NUM_OF_ELEMENTS_IN_LINE) : 0]                                         log_status;

localparam  STATE_INIT                    = 0,
            STATE_REORDER                 = 1,
            STATE_READ                    = 2;

reg [4 : 0] state;

wire    [TENSOR_DIMENSIONS-1 : 0][MODE_TENSOR_BLOCK_WIDTH-1 : 0]        block_ids;
wire    [TENSOR_DIMENSIONS-1 : 0][MODE_TENSOR_ADDR_WIDTH-1 : 0]         tensor_addrs;
wire    [TENSOR_DATA_WIDTH-1 : 0]                                       tensor_value;
wire    [MODE_TENSOR_ADDR_WIDTH-1 : 0]                                  base_mode_addr;
wire    [MODE_TENSOR_BLOCK_WIDTH-1 : 0]                                 base_block_id;
wire    [TENSOR_DIMENSIONS-2 : 0][MODE_TENSOR_ADDR_WIDTH-1 : 0]         rest_of_mode_addr;
wire    [TENSOR_DIMENSIONS-2 : 0][MODE_TENSOR_BLOCK_WIDTH-1 : 0]        rest_of_block_ids;

wire [TENSOR_WIDTH-1 : 0]                                               reconstructed_tensor_element;
reg  [TENSOR_WIDTH-1 : 0]                                               reg_reconstructed_tensor_element;
reg  [$clog2(NUM_OF_SHARDS)-1 : 0]                                      reg_base_mode_addr;

assign {block_ids, tensor_addrs, tensor_value}  = input_tensor_element;
assign base_mode_addr                   = tensor_addrs[TENSOR_DIMENSIONS-1];
assign rest_of_mode_addr                = tensor_addrs[TENSOR_DIMENSIONS-2 : 0];
assign base_block_id                    = block_ids[TENSOR_DIMENSIONS-1];
assign rest_of_block_ids                = block_ids[TENSOR_DIMENSIONS-2 : 0];
assign reconstructed_tensor_element     = {rest_of_block_ids,base_block_id,rest_of_mode_addr,base_mode_addr,tensor_value};

always @(posedge clk) begin
    if (~rst) begin
        state       <= STATE_INIT;
        log_status  <= 0;
        output_tensor_element_en    <= 0;
    end
    else begin
        output_tensor_element_en                        <= 0;
        if (state == STATE_INIT) begin
            if(input_tensor_element_en) begin
                reg_reconstructed_tensor_element        <= reconstructed_tensor_element;
                reg_base_mode_addr                      <= base_mode_addr[$clog2(NUM_OF_SHARDS)-1 : 0];
                state                                   <= STATE_REORDER;
            end
            
        end else if(state == STATE_REORDER) begin
            log_status[reg_base_mode_addr]                  <= log_status[reg_base_mode_addr] + 1;
            tensor_element_blk_addr_in                      <= reg_base_mode_addr;
            tensor_element_blk_in_en                        <= 1 << log_status[reg_base_mode_addr];
            tensor_element_blk_out_en                       <= 1;
            tensor_element_blk_in                           <= reg_reconstructed_tensor_element;
            tensor_element_blk_addr_out                     <= reg_base_mode_addr;
            state                                           <= STATE_READ;

        end else if (state == STATE_READ) begin
            if(log_status[reg_base_mode_addr] == NUM_OF_ELEMENTS_IN_LINE) begin
                log_status[reg_base_mode_addr]          <= 0;
                output_tensor_element                   <= tensor_element_blk_out;
                output_tensor_element_en                <= 1;
            end
            state                                       <= STATE_INIT;
        end
    end
end

generate
    for (i = 0; i < NUM_OF_ELEMENTS_IN_LINE ; i = i + 1) begin: REORDER_MEMORY
        BRAM_REORDER_TENSOR UUT_BRAM_REORDER_TENSOR (
            .clka(clk),
            .ena(tensor_element_blk_in_en[i]),
            .wea(tensor_element_blk_in_en[i]),
            .addra(tensor_element_blk_addr_in),
            .dina(tensor_element_blk_in),
            .clkb(clk),
            .enb(tensor_element_blk_out_en),
            .addrb(tensor_element_blk_addr_out),
            .doutb(tensor_element_blk_out[i])
        );
    end
endgenerate

endmodule
