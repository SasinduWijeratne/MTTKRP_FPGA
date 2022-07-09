`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/06/2021 11:15:42 PM
// Design Name: 
// Module Name: accel_mttkrp
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


module accel_mttkrp #(
    parameter TENSOR_WIDTH              = 128,
    parameter TENSOR_DIMENSIONS         = 3,
    parameter FACTOR_MATRIX_WIDTH       = 32,
    parameter RANK_FACTOR_MATRIX        = 16,
    parameter NUM_INTERNAL_MEM_TENSOR   = 1024,
    parameter TENSOR_DATA_WIDTH         = 32,
    parameter MODE_TENSOR_BLOCK_WIDTH   = 16,
    parameter MODE_TENSOR_ADDR_WIDTH    = 16

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
    output   reg [TENSOR_DIMENSIONS-2 : 0]                                                              output_factor_matrices_addr_en,
    output   wire [TENSOR_DIMENSIONS-2 : 0] [MODE_TENSOR_ADDR_WIDTH-1 : 0]                              output_factor_matrices_addr,
    output   reg                                                                                        op_done_ack,
    output  reg                                                                                         output_to_adder_tree_en,
    output  reg                                                                                         ready_receive_tensor,
    output  reg [RANK_FACTOR_MATRIX-1 : 0] [FACTOR_MATRIX_WIDTH-1 : 0]                                  output_to_adder_tree
    );


localparam RANK_DATA_WIDTH          = FACTOR_MATRIX_WIDTH*RANK_FACTOR_MATRIX;
localparam STATE_BITS               = 3;

localparam  STATE_INIT                    = 0,
            STATE_IDLE                    = 1,
            STATE_SEND_ADDR               = 2,
            STATE_INTERMEDIATE_CAPT       = 3,
            STATE_COMPUTE                 = 4,
            STATE_STORE                   = 5,
            STATE_DONE                    = 6,
            STATE_OVER                    = 7;

reg     [NUM_INTERNAL_MEM_TENSOR-1 : 0]                 initialize_internal_mem;


reg                                                      out_fact_mat_read_en;
reg                                                      out_fact_mat_write_en;
reg     [$clog2(NUM_INTERNAL_MEM_TENSOR)-1 : 0]          out_fact_mat_read_addr;
reg     [$clog2(NUM_INTERNAL_MEM_TENSOR)-1 : 0]          out_fact_mat_write_addr;
wire     [RANK_DATA_WIDTH-1 : 0]                         out_fact_mat_read_out;
wire     [RANK_DATA_WIDTH-1 : 0]                         out_fact_mat_write_in;

wire    [TENSOR_DIMENSIONS-1 : 0][MODE_TENSOR_BLOCK_WIDTH-1 : 0]        block_ids;
wire    [TENSOR_DIMENSIONS-1 : 0][MODE_TENSOR_ADDR_WIDTH-1 : 0]         tensor_addrs;
wire    [TENSOR_DATA_WIDTH-1 : 0]                                       tensor_value;

wire    [MODE_TENSOR_ADDR_WIDTH-1 : 0]                                  base_mode_addr;

reg     [FACTOR_MATRIX_WIDTH-1 : 0] [RANK_FACTOR_MATRIX-1 : 0]          intermediate_val_keeper;
reg     [RANK_FACTOR_MATRIX-1 : 0][TENSOR_DATA_WIDTH - 1 : 0]           compute_inter_val;
reg     [RANK_FACTOR_MATRIX-1 : 0][TENSOR_DATA_WIDTH - 1 : 0]           mult_inter_val;


reg     [STATE_BITS-1 : 0]                                              state;

reg     [$clog2(NUM_INTERNAL_MEM_TENSOR)-1 : 0]                           out_counter;



integer                                                                 I,J;  

assign {block_ids, tensor_addrs, tensor_value}  = tensor_element;

assign base_mode_addr                   = tensor_addrs[TENSOR_DIMENSIONS-1];
assign output_factor_matrices_addr      = tensor_addrs[TENSOR_DIMENSIONS-2 : 0];
assign out_fact_mat_write_in            = compute_inter_val;




/*                      logic                           */
always @(posedge clk) begin: STATE_MACHINE
    if(~rst) begin
    
        initialize_internal_mem                 = {(NUM_INTERNAL_MEM_TENSOR){1'b0}};
        state                                   = STATE_INIT;
        output_factor_matrices_addr_en          = 0;
        op_done_ack                             = 0;
        out_fact_mat_read_en                    = 0;

        mult_inter_val                          = 1;
        compute_inter_val                       = 0;
        out_fact_mat_write_en                   = 0;

        out_counter                             = 0;

        output_to_adder_tree_en                 = 0;
        out_counter                             = 0;
        ready_receive_tensor                    = 0;

    end else begin

        out_fact_mat_read_addr                  = base_mode_addr[$clog2(NUM_INTERNAL_MEM_TENSOR)-1 : 0];
        out_fact_mat_write_addr                 = base_mode_addr[$clog2(NUM_INTERNAL_MEM_TENSOR)-1 : 0];

        op_done_ack                             = 0;
        output_factor_matrices_addr_en          = 0;
        out_fact_mat_read_en                    = 0;
        out_fact_mat_write_en                   = 0;
        output_to_adder_tree_en                 = 0;
        ready_receive_tensor                    = 0;

        output_to_adder_tree                    = out_fact_mat_read_out;

        case (state)
            STATE_INIT: begin
                out_counter                             = 0;
                initialize_internal_mem                 = {(NUM_INTERNAL_MEM_TENSOR){1'b0}};
                if (begining_of_shard) begin
                    state                               = STATE_IDLE;
                end
            end
            STATE_IDLE: begin
                mult_inter_val                          = 0;
                compute_inter_val                       = 0;
                ready_receive_tensor                    = 1;

                if(tensor_element_en) begin
                    state                               = STATE_SEND_ADDR;
                    output_factor_matrices_addr_en      = {(TENSOR_DIMENSIONS-2){1'b1}};
                end
            end
            STATE_SEND_ADDR: begin
                if((&input_factor_matrices_en) & tensor_element_en) begin
                    state                       = STATE_INTERMEDIATE_CAPT;
                    out_fact_mat_read_en        = 1'b1;
                end
            end
            STATE_INTERMEDIATE_CAPT: begin
                intermediate_val_keeper         = out_fact_mat_read_out;
                state                           = STATE_COMPUTE;
            end
            STATE_COMPUTE: begin
                initialize_internal_mem[out_fact_mat_read_addr] = 1'b1;

                for (J = 0; J < RANK_FACTOR_MATRIX; J = J+1) begin
                    mult_inter_val[J] = input_factor_matrices[0][J];
                    for (I = 1; I < TENSOR_DIMENSIONS-1; I = I+1) begin
                        mult_inter_val[J]              = mult_inter_val[J] * input_factor_matrices[I][J];
                    end
                end

                if(initialize_internal_mem[out_fact_mat_read_addr] == 1'b1) begin
                    for (J = 0; J < RANK_FACTOR_MATRIX; J = J + 1) begin
                        compute_inter_val[J]          = intermediate_val_keeper[J] + mult_inter_val[J];
                    end

                end
                else begin
                    for (J = 0; J < RANK_FACTOR_MATRIX; J = J + 1) begin
                        compute_inter_val[J]          = mult_inter_val[J];
                    end
                end

                state                         = STATE_STORE;

            end
            STATE_STORE: begin
                out_fact_mat_write_en       = 1;
                state                       = STATE_DONE;
            end
            STATE_DONE: begin
                op_done_ack                 = 1;
                if(end_of_shard) begin
                    state                       = STATE_OVER;
                end 
                else begin
                    state                       = STATE_IDLE;
                end
                
            end
            STATE_OVER: begin
                
                initialize_internal_mem                 = {(NUM_INTERNAL_MEM_TENSOR){1'b0}};
                out_fact_mat_read_addr                  = out_counter;

                if(adder_tree_ready_to_receive) begin
                    output_to_adder_tree_en                 = 1;
                    out_counter                             = out_counter + 1;
                    out_fact_mat_read_en                    = 1;
                end
                if(out_counter == NUM_INTERNAL_MEM_TENSOR) begin
                    state                                   = STATE_INIT;
                end
                
            end

            default: begin
                state                                   = STATE_IDLE;
            end

        endcase


    end
end





/*       Module initialization         */
//Intermediate_val_holder inst_out_fact_mat(
//    .clka(clk),
//    .ena(out_fact_mat_write_en),
//    .wea(out_fact_mat_write_en),
//    .addra(out_fact_mat_write_addr),
//    .dina(out_fact_mat_write_in),
//    .clkb(clk),
//    .enb(out_fact_mat_read_en),
//    .addrb(out_fact_mat_read_addr),
//    .doutb(out_fact_mat_read_out)
//  );

RAM_param inst_out_fact_mat(
    .clk(clk),
    .read_write(out_fact_mat_write_en),
//    .wea(out_fact_mat_write_en),
    .addr(out_fact_mat_write_addr),
    .data_in(out_fact_mat_write_in),
    .data_out(out_fact_mat_read_out)
  );



endmodule


 module RAM_param(clk, addr, read_write, clear, data_in, data_out);
parameter n = 10;
parameter w = 512;

input clk, read_write, clear;
input [n-1:0] addr;
input [w-1:0] data_in;
output reg [w-1:0] data_out;

// Start module here!
reg [w-1:0] reg_array [2**n-1:0];

integer i;
initial begin
    for( i = 0; i < 2**n; i = i + 1 ) begin
        reg_array[i] = 0;
    end
end

always @(posedge clk) begin
    if( read_write == 1 )
        reg_array[addr] = data_in;
    //if( clear == 1 ) begin
        //for( i = 0; i < 2**n; i = i + 1 ) begin
            //reg_array[i] <= 0;
        //end
    //end
    data_out = reg_array[addr];
end
endmodule  
