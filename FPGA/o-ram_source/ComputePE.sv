`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/27/2021 01:07:53 PM
// Design Name: 
// Module Name: ComputePE
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

module ComputePE #(
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
    parameter NUM_COMPUTE_UNITS         = 8
)(
    input   wire                                                                                        clk,
    input   wire                                                                                        rst,
    input   wire                                                                                        begining_of_shard,
    input   wire                                                                                        end_of_shard,
    input   wire                                                                                        factor_data_ack,
    input   wire                                                                                        adder_tree_ready_to_receive,
    input   wire                                                                                        tensor_element_en,
    input   wire [TENSOR_WIDTH-1 : 0]                                                                   tensor_element, // | BL_X | BL_Y | BL_Z | X | Y | Z | VAL |
    input   wire [TENSOR_DIMENSIONS-2 : 0]                                                              input_factor_matrices_en,
    input   wire [TENSOR_DIMENSIONS-2 : 0] [RANK_FACTOR_MATRIX-1 : 0] [FACTOR_MATRIX_WIDTH-1 : 0]       input_factor_matrices,
    input   wire [$clog2(NUM_COMPUTE_UNITS) : 0]                                                        input_compute_id_factor_matrices,                                                                                     
    output   reg [TENSOR_DIMENSIONS-2 : 0]                                                              output_factor_matrices_addr_en,
    output   reg [TENSOR_DIMENSIONS-2 : 0] [MODE_TENSOR_ADDR_WIDTH-1 : 0]                               output_factor_matrices_addr,
    output   reg [$clog2(NUM_COMPUTE_UNITS) : 0]                                                        output_compute_id_factor_matrices,
    output   reg                                                                                        op_done_ack,
    output  wire                                                                                        output_to_adder_tree_en,
    output  wire [RANK_FACTOR_MATRIX-1 : 0] [FACTOR_MATRIX_WIDTH-1 : 0]                                 output_to_adder_tree
//    output   wire                                                                                       reordered_tensor_element_en,
//    output   wire [TENSOR_WIDTH-1 : 0]                                                                  reordered_tensor_element // | BL_X | BL_Y | BL_Z | X | Y | Z | VAL |
    );

data_flow_accel_mttkrp 
#(
    .TENSOR_WIDTH            (TENSOR_WIDTH            ),
    .TENSOR_DIMENSIONS       (TENSOR_DIMENSIONS       ),
    .FACTOR_MATRIX_WIDTH     (FACTOR_MATRIX_WIDTH     ),
    .RANK_FACTOR_MATRIX      (RANK_FACTOR_MATRIX      ),
    .NUM_INTERNAL_MEM_TENSOR (NUM_INTERNAL_MEM_TENSOR ),
    .TENSOR_DATA_WIDTH       (TENSOR_DATA_WIDTH       ),
    .MODE_TENSOR_BLOCK_WIDTH (MODE_TENSOR_BLOCK_WIDTH ),
    .MODE_TENSOR_ADDR_WIDTH  (MODE_TENSOR_ADDR_WIDTH  ),
    .NUM_COMPUTE_UNITS       (NUM_COMPUTE_UNITS       )
)
u_data_flow_accel_mttkrp(
    .clk                               (clk                               ),
    .rst                               (rst                               ),
    .begining_of_shard                 (begining_of_shard                 ),
    .end_of_shard                      (end_of_shard                      ),
    .factor_data_ack                   (factor_data_ack                   ),
    .adder_tree_ready_to_receive       (adder_tree_ready_to_receive       ),
    .tensor_element_en                 (tensor_element_en                 ),
    .tensor_element                    (tensor_element                    ),
    .input_factor_matrices_en          (input_factor_matrices_en          ),
    .input_factor_matrices             (input_factor_matrices             ),
    .input_compute_id_factor_matrices  (input_compute_id_factor_matrices  ),
    .output_factor_matrices_addr_en    (output_factor_matrices_addr_en    ),
    .output_factor_matrices_addr       (output_factor_matrices_addr       ),
    .output_compute_id_factor_matrices (output_compute_id_factor_matrices ),
    .op_done_ack                       (op_done_ack                       ),
    .output_to_adder_tree_en           (output_to_adder_tree_en           ),
    .output_to_adder_tree              (output_to_adder_tree              )
);

//tensor_reordering_system 
//#(
//    .TENSOR_WIDTH            (TENSOR_WIDTH            ),
//    .TENSOR_DIMENSIONS       (TENSOR_DIMENSIONS       ),
//    .NUM_OF_SHARDS           (NUM_OF_SHARDS           ),
//    .TENSOR_DATA_WIDTH       (TENSOR_DATA_WIDTH       ),
//    .MODE_TENSOR_BLOCK_WIDTH (MODE_TENSOR_BLOCK_WIDTH ),
//    .DMA_DATA_WIDTH          (DMA_DATA_WIDTH          ),
//    .MODE_TENSOR_ADDR_WIDTH  (MODE_TENSOR_ADDR_WIDTH  )
//)
//u_tensor_reordering_system(
//    .clk                      (clk                      ),
//    .rst                      (rst                      ),
//    .input_tensor_element_en  (tensor_element_en        ),
//    .input_tensor_element     (tensor_element           ),
//    .output_tensor_element_en (reordered_tensor_element_en),
//    .output_tensor_element    (reordered_tensor_element)
//);

endmodule
