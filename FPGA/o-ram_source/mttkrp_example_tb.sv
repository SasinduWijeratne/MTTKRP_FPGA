`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/29/2021 11:13:19 PM
// Design Name: 
// Module Name: mttkrp_example_tb
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


module mttkrp_example_tb#(
  parameter SIMULATION       = "FALSE",   // This parameter must be
                                          // TRUE for simulations and 
                                          // FALSE for implementation.
                                          //
  parameter APP_DATA_WIDTH   = 32,        // Application side data bus width.
                                          // It is 8 times the DQ_WIDTH.
                                          //
  parameter APP_ADDR_WIDTH   = 32,        // Application side Address bus width.
                                          // It is sum of COL, ROW and BANK address
                                          // for DDR3. It is sum of COL, ROW, 
                                          // Bank Group and BANK address for DDR4.
                                          //
  parameter nCK_PER_CLK      = 4,         // Fabric to PHY ratio
                                          //
  parameter MEM_ADDR_ORDER   = "ROW_COLUMN_BANK", // Application address order.
                                                 // "ROW_COLUMN_BANK" is the default
                                                 // address order. Refer to product guide
                                                 // for other address order options.
parameter 	LEN_ADDR 			=	32,
parameter 	LEN_PROCESSOR_NO 	= 	 7,
parameter   LEN_SLOT_ID         =    7,
parameter 	RHS_BURST_LEN 		= 	 4,
parameter 	LEN_DATA_RHS 	    = 	512,
parameter 	LEN_FLIT_DATA_LHS 	= 	608
  )
  (
  // ********* ALL SIGNALS AT THIS INTERFACE ARE ACTIVE HIGH SIGNALS ********/
  input clk,                 // MC UI clock.
  input mem_clk,
                             //
  input rst,                 // MC UI reset signal.
  input logic_reset,                           //
  input init_calib_complete, // MC calibration done signal coming from MC UI.
                             //
  input app_rdy,             // cmd fifo ready signal coming from MC UI.
                             //
  input app_wdf_rdy,         // write data fifo ready signal coming from MC UI.
                             //
  input app_rd_data_valid,   // read data valid signal coming from MC UI
                             //
  input [APP_DATA_WIDTH-1 : 0]  app_rd_data, // read data bus coming from MC UI
                                             //
  output [2 : 0]                app_cmd,     // command bus to the MC UI
                                             //
  output [APP_ADDR_WIDTH-1 : 0] app_addr,    // address bus to the MC UI
                                             //
  output                        app_en,      // command enable signal to MC UI.
                                             //
  output [(APP_DATA_WIDTH/8)-1 : 0] app_wdf_mask, // write data mask signal which
                                                  // is tied to 0 in this example
                                                  // 
  output [APP_DATA_WIDTH-1: 0]  app_wdf_data, // write data bus to MC UI.
                                              //
  output                        app_wdf_end,  // write burst end signal to MC UI
                                              //
  output                        app_wdf_wren, // write enable signal to MC UI
                                              //
  output                        compare_error,// Memory READ_DATA and example TB
                                              // WRITE_DATA compare error.
  output                        wr_rd_complete                                               
                                              
  );


wire [APP_DATA_WIDTH-1 : 0]  temp_app_rd_data;
wire [LEN_DATA_RHS-1: 0]   temp_app_wdf_data;
wire                         out_ready_to_receive_top;

//*****************************************************************************
// Write data mask to the MC
// ** The write data mask is set to zero in this example_tb **
// This is the simple traffic generator, if write data mask is toggled
// more logic would be required to qualify the read data.
// To keep it simple and have less logic write data mask is always held low.
//*****************************************************************************
// The app_wdf_mask signal tied to 0 in this example.
// If the mask signal need to be toggled, the timing is same as write data.
//*****************************************************************************
assign app_wdf_mask   = 0 ;

assign app_wdf_data = {{(APP_DATA_WIDTH-LEN_DATA_RHS){1'b0}},temp_app_wdf_data};


mttkrp_wrapper_top_cache 
// #(
//     .LEN_MEM_DATA            (LEN_MEM_DATA            ),
//     .LEN_ADDR                (LEN_ADDR                ),
//     .TENSOR_WIDTH            (TENSOR_WIDTH            ),
//     .TENSOR_DIMENSIONS       (TENSOR_DIMENSIONS       ),
//     .FACTOR_MATRIX_WIDTH     (FACTOR_MATRIX_WIDTH     ),
//     .RANK_FACTOR_MATRIX      (RANK_FACTOR_MATRIX      ),
//     .NUM_INTERNAL_MEM_TENSOR (NUM_INTERNAL_MEM_TENSOR ),
//     .TENSOR_DATA_WIDTH       (TENSOR_DATA_WIDTH       ),
//     .MODE_TENSOR_BLOCK_WIDTH (MODE_TENSOR_BLOCK_WIDTH ),
//     .MODE_TENSOR_ADDR_WIDTH  (MODE_TENSOR_ADDR_WIDTH  ),
//     .NUM_OF_SHARDS           (NUM_OF_SHARDS           ),
//     .DMA_DATA_WIDTH          (DMA_DATA_WIDTH          ),
//     .NUM_COMPUTE_UNITS       (NUM_COMPUTE_UNITS       )
// )
u_mttkrp_wrapper_top_cache(
    .clk                      (clk                      ),
    .mem_clk                  (mem_clk                  ),
    .rst                      (rst                      ),
    .in_RHS_data_top          (in_RHS_data_top          ),
    .in_RHS_in_data_ready_top (in_RHS_in_data_ready_top ),
    .in_RHS_avl_top           (in_RHS_avl_top           ),
    .out_RHS_addr_top         (out_RHS_addr_top         ),
    .out_RHS_data_top         (out_RHS_data_top         ),
    .out_RHS_wrt_en_top       (out_RHS_wrt_en_top       ),
    .out_ready_to_receive_top (out_ready_to_receive_top ),
    .out_RHS_avl_top          (out_RHS_avl_top          ),
    .out_burst_done           (out_burst_done           )
);

assign app_cmd = {1'b0,~app_wdf_wren};

endmodule
