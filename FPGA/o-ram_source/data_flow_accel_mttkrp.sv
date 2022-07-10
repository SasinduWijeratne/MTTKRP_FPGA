`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/11/2021 01:40:59 AM
// Design Name: 
// Module Name: data_flow_accel_mttkrp
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


module data_flow_accel_mttkrp #(
    parameter TENSOR_WIDTH              = 128,
    parameter TENSOR_DIMENSIONS         = 3,
    parameter FACTOR_MATRIX_WIDTH       = 32,
    parameter RANK_FACTOR_MATRIX        = 16,
    parameter NUM_INTERNAL_MEM_TENSOR   = 1024,
    parameter TENSOR_DATA_WIDTH         = 32,
    parameter MODE_TENSOR_BLOCK_WIDTH   = 16,
    parameter MODE_TENSOR_ADDR_WIDTH    = 16,
    parameter NUM_COMPUTE_UNITS         = 320
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
    output   reg [TENSOR_DIMENSIONS-2 : 0] [MODE_TENSOR_ADDR_WIDTH-1 : 0]                              output_factor_matrices_addr,
    output   reg [$clog2(NUM_COMPUTE_UNITS) : 0]                                                       output_compute_id_factor_matrices,
    output   reg                                                                                        op_done_ack,
    output  wire                                                                                        output_to_adder_tree_en,
    output  wire [RANK_FACTOR_MATRIX-1 : 0] [FACTOR_MATRIX_WIDTH-1 : 0]                                 output_to_adder_tree
    );

genvar ik;

integer pp,j,jj,jjj,k,kk;


wire    [NUM_COMPUTE_UNITS-1 : 0][$clog2(NUM_COMPUTE_UNITS) : 0]                                                            output_compute_id;


wire    [NUM_COMPUTE_UNITS-1 : 0]                                                                                           output_to_adder_tree_en_ik;
wire    [NUM_COMPUTE_UNITS-1 : 0][RANK_FACTOR_MATRIX-1 : 0] [FACTOR_MATRIX_WIDTH-1 : 0]                                     output_to_adder_tree_ik;


wire    [NUM_COMPUTE_UNITS-1 : 0]                                                                                           ready_receive_tensor;
reg    [NUM_COMPUTE_UNITS-1 : 0]                                                                                            tensor_element_en_ik;

reg     [NUM_COMPUTE_UNITS-1 : 0]                                                                                            input_factor_matrices_en_ik;
reg     [NUM_COMPUTE_UNITS-1 : 0][TENSOR_DIMENSIONS-2 : 0]                                                                   output_factor_matrices_addr_en_ik;
reg     [NUM_COMPUTE_UNITS-1 : 0][TENSOR_DIMENSIONS-2 : 0][MODE_TENSOR_ADDR_WIDTH-1 : 0]                                     output_factor_matrices_addr_ik;

reg    [$clog2(NUM_COMPUTE_UNITS) : 0]                                                                                     selected_pe;

wire     [NUM_COMPUTE_UNITS-1 : 0]                                                                                         op_done_ack_ik;

always@(*) begin
    op_done_ack     <= 0;
    for(pp = 0; pp < NUM_COMPUTE_UNITS; pp = pp+1) begin
        op_done_ack <= op_done_ack|op_done_ack_ik[pp];
    
    end
end


always @(posedge clk) begin
    if (~rst) begin
        selected_pe         <= NUM_COMPUTE_UNITS;
    end else begin
        for (j = NUM_COMPUTE_UNITS-1; j >= 0; j = j - 1) begin
            if(ready_receive_tensor[j]) begin
                if (selected_pe < j) begin
                    selected_pe <= j;
                end
            end
        end
      if (ready_receive_tensor[selected_pe] == 0) begin
            selected_pe         <= NUM_COMPUTE_UNITS;
        end
    end
end


always @(*) begin
    for (k = 0; k < NUM_COMPUTE_UNITS; k = k+1) begin
        tensor_element_en_ik[k]     <= 0;
        if (tensor_element_en) begin
            if(selected_pe == k) begin
                tensor_element_en_ik[k]     <= 1;
            end
        end 
    end
end

always@(*) begin 
    for (jj = 0; jj < NUM_COMPUTE_UNITS; jj = jj + 1) begin
        input_factor_matrices_en_ik[jj]         <= 0;
        if((&input_factor_matrices_en) == 1'b1) begin
            if(jj == input_compute_id_factor_matrices) begin
                input_factor_matrices_en_ik[jj]         <= 1;
            end
         end
    end
end

always@(*) begin 
    output_factor_matrices_addr              <= 0;
    output_factor_matrices_addr_en           <= 0;
    output_compute_id_factor_matrices        <= NUM_COMPUTE_UNITS;
    for (jjj = 0; jjj < NUM_COMPUTE_UNITS; jjj = jjj + 1) begin
        if(output_factor_matrices_addr_en_ik[jjj] == 1) begin
            output_factor_matrices_addr          <= output_factor_matrices_addr_ik[jjj];
            output_factor_matrices_addr_en       <= 1;
            output_compute_id_factor_matrices    <= jjj;
        end
    end
end



generate
    for (ik = 0; ik < NUM_COMPUTE_UNITS; ik = ik + 1) begin: INIT_MIRROR_COMPUTE
        mirror_accel_mttkrp 
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
//            .COMPUTE_ID              (ik                      )
        )
        u_mirror_accel_mttkrp(
        	.clk                            (clk                            ),
            .rst                            (rst                            ),
            .begining_of_shard              (begining_of_shard              ),
            .end_of_shard                   (end_of_shard                   ),
            .factor_data_ack                (factor_data_ack                ),
            .adder_tree_ready_to_receive    (adder_tree_ready_to_receive    ),
            .tensor_element_en              (tensor_element_en_ik[ik]       ),
            .tensor_element                 (tensor_element                 ),
            .input_factor_matrices_en       (input_factor_matrices_en_ik[ik]),
            .input_factor_matrices          (input_factor_matrices          ),
            .output_factor_matrices_addr_en (output_factor_matrices_addr_en_ik[ik]),
            .output_factor_matrices_addr    (output_factor_matrices_addr_ik[ik]),
            .op_done_ack                    (op_done_ack_ik[ik]              ),
            .output_to_adder_tree_en        (output_to_adder_tree_en_ik[ik] ),
            .output_to_adder_tree           (output_to_adder_tree_ik[ik]    ),
            .output_compute_id              (output_compute_id[ik]          ),
            .ready_receive_tensor           (ready_receive_tensor[ik]       )
        );
          
    end
endgenerate


adder_tree #(
    .NUM_TOT_ELEMENT(NUM_COMPUTE_UNITS),
    .N(FACTOR_MATRIX_WIDTH)
) 
u_addr_tree(
    .clk(clk),
    .rst(rst),
	.in_avl(output_to_adder_tree_en_ik),
    .adder_inputs(output_to_adder_tree_ik),
	.out_avl(output_to_adder_tree_en),
	.c(output_to_adder_tree)
    );



endmodule
