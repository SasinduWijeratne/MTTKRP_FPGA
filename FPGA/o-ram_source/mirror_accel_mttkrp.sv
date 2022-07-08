`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/24/2021 06:18:11 PM
// Design Name: 
// Module Name: mirror_accel_mttkrp
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


module mirror_accel_mttkrp #(
    parameter TENSOR_WIDTH              = 128,
    parameter TENSOR_DIMENSIONS         = 3,
    parameter FACTOR_MATRIX_WIDTH       = 32,
    parameter RANK_FACTOR_MATRIX        = 16,
    parameter NUM_INTERNAL_MEM_TENSOR   = 1024,
    parameter TENSOR_DATA_WIDTH         = 32,
    parameter MODE_TENSOR_BLOCK_WIDTH   = 16,
    parameter MODE_TENSOR_ADDR_WIDTH    = 16,
    parameter NUM_COMPUTE_UNITS         = 4,
    parameter COMPUTE_ID                = 0
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

    output   wire [TENSOR_DIMENSIONS-2 : 0]                                                              output_factor_matrices_addr_en,
    output   wire [TENSOR_DIMENSIONS-2 : 0] [MODE_TENSOR_ADDR_WIDTH-1 : 0]                              output_factor_matrices_addr,
    output   wire                                                                                        op_done_ack,

    output  wire                                                                                         output_to_adder_tree_en,
    output  wire [RANK_FACTOR_MATRIX-1 : 0] [FACTOR_MATRIX_WIDTH-1 : 0]                                  output_to_adder_tree,
    output  wire [$clog2(NUM_COMPUTE_UNITS) : 0]                                                         output_compute_id,
    output  wire                                                                                         ready_receive_tensor

    );  
    
localparam  NUM_OF_MIRRORS            = 2; // In mirror -> 2 is constant


reg           [NUM_OF_MIRRORS-1 : 0]                                                                           begining_of_shard_ir;
reg           [NUM_OF_MIRRORS-1 : 0]                                                                           end_of_shard_ir;
reg                                                                                                            intermediate_swap;  


wire [NUM_OF_MIRRORS-1 : 0][TENSOR_DIMENSIONS-2 : 0]                                                              output_factor_matrices_addr_en_ir;
wire [NUM_OF_MIRRORS-1 : 0][TENSOR_DIMENSIONS-2 : 0] [MODE_TENSOR_ADDR_WIDTH-1 : 0]                               output_factor_matrices_addr_ir;
wire [NUM_OF_MIRRORS-1 : 0]                                                                                       op_done_ack_ir;
wire [NUM_OF_MIRRORS-1 : 0]                                                                                       output_to_adder_tree_en_ir;
wire [NUM_OF_MIRRORS-1 : 0][RANK_FACTOR_MATRIX-1 : 0] [FACTOR_MATRIX_WIDTH-1 : 0]                                 output_to_adder_tree_ir;
wire [NUM_OF_MIRRORS-1 : 0]                                                                                       ready_receive_tensor_ir;


assign output_factor_matrices_addr_en     = output_factor_matrices_addr_en_ir[0] | output_factor_matrices_addr_en_ir[1]; 
assign output_factor_matrices_addr        = output_factor_matrices_addr_ir[0] | output_factor_matrices_addr_ir[1];
assign op_done_ack                        = op_done_ack_ir[0] | op_done_ack_ir[1];
assign output_to_adder_tree_en            = output_to_adder_tree_en_ir[0] | output_to_adder_tree_en_ir[1];
assign output_to_adder_tree               = output_to_adder_tree_ir[0] | output_to_adder_tree_ir[1];

assign output_compute_id = COMPUTE_ID;

assign ready_receive_tensor = ready_receive_tensor_ir[0] | ready_receive_tensor_ir[1];


always @(posedge clk) begin
    if(~rst) begin
        begining_of_shard_ir        <= 0;
        end_of_shard_ir             <= 0;
        intermediate_swap           <= 0;
    end
    else begin
        if(op_done_ack) begin
            intermediate_swap <= ~intermediate_swap;
        end
            if(begining_of_shard) begin
                if(intermediate_swap) begin
                    begining_of_shard_ir[0]            <= 0;
                    begining_of_shard_ir[1]            <= 1;              
                end
                else begin
                    begining_of_shard_ir[0]            <= 1;
                    begining_of_shard_ir[1]            <= 0;                  
                end
            end

            if(end_of_shard) begin
                if(intermediate_swap) begin
                    end_of_shard_ir[0]                 <= 0;
                    end_of_shard_ir[1]                 <= 1;                
                end
                else begin
                    end_of_shard_ir[0]                 <= 1;
                    end_of_shard_ir[1]                 <= 0;                  
                end                
            end



    end
end


genvar ir;


generate
    for(ir = 0; ir < NUM_OF_MIRRORS; ir = ir + 1) begin: COMPUTE_PE 
        accel_mttkrp 
        #(
            .TENSOR_WIDTH            (TENSOR_WIDTH            ),
            .TENSOR_DIMENSIONS       (TENSOR_DIMENSIONS       ),
            .FACTOR_MATRIX_WIDTH     (FACTOR_MATRIX_WIDTH     ),
            .RANK_FACTOR_MATRIX      (RANK_FACTOR_MATRIX      ),
            .NUM_INTERNAL_MEM_TENSOR (NUM_INTERNAL_MEM_TENSOR ),
            .TENSOR_DATA_WIDTH       (TENSOR_DATA_WIDTH       ),
            .MODE_TENSOR_BLOCK_WIDTH (MODE_TENSOR_BLOCK_WIDTH ),
            .MODE_TENSOR_ADDR_WIDTH  (MODE_TENSOR_ADDR_WIDTH  )
        )
        u_accel_mttkrp(
            .clk                            (clk                            ),
            .rst                            (rst                            ),
            .begining_of_shard              (begining_of_shard_ir[ir]       ),
            .end_of_shard                   (end_of_shard_ir[ir]            ),
            .factor_data_ack                (factor_data_ack                ),
            .adder_tree_ready_to_receive    (adder_tree_ready_to_receive    ),
            .tensor_element_en              (tensor_element_en              ),
            .tensor_element                 (tensor_element                 ),
            .input_factor_matrices_en       (input_factor_matrices_en       ),
            .input_factor_matrices          (input_factor_matrices          ),
            .output_factor_matrices_addr_en (output_factor_matrices_addr_en_ir[ir] ),
            .output_factor_matrices_addr    (output_factor_matrices_addr_ir[ir]    ),
            .op_done_ack                    (op_done_ack_ir[ir]                    ),
            .output_to_adder_tree_en        (output_to_adder_tree_en_ir[ir]        ),
            .ready_receive_tensor           (ready_receive_tensor_ir[ir]           ),
            .output_to_adder_tree           (output_to_adder_tree_ir[ir]           )
        );
    end
endgenerate    
    
    
endmodule
