/******************************************************************************
// (c) Copyright 2013 - 2014 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
******************************************************************************/
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor             : Xilinx
// \   \   \/     Version            : 1.0
//  \   \         Application        : MIG
//  /   /         Filename           : example_tb.sv
// /___/   /\     Date Last Modified : $Date: 2014/09/03 $
// \   \  /  \    Date Created       : Thu Apr 18 2013
//  \___\/\___\
//
// Device           : UltraScale
// Design Name      : DDRx SDRAM EXAMPLE TB
// Purpose          : This is an  example test-bench that shows how to interface
//                    to the Memory controller (MC) User Interface (UI). This example 
//                    works for DDR3/4 memory controller generated from MIG. 
//                    This module waits for the calibration complete 
//                    (init_calib_complete) to pass the traffic to the MC.
//
//                    This TB generates 100 write transactions 
//                    followed by 100 read transactions to the MC.
//                    Checks if the data that is read back from the 
//                    memory is correct. After 100 writes and reads, no other
//                    commands will be issued by this TG.
//
//                    All READ and WRITE transactions in this example TB are of 
//                    DDR3/4 BURST LENGTH (BL) 8. In a single clock cycle 1 BL8
//                    transaction will be generated.
//
//                    The fabric to DRAM clock ratio is 4:1. In each fabric 
//                    clock cycle 8 beats of data will be written during 
//                    WRITE transactions and 8 beats of data will be received 
//                    during READ transactions.
//
//                    The results of this example_tb is guaranteed only for  
//                    100 write and 100 read transactions.
//                    The results of this example_tb is not guaranteed beyond 
//                    100 write and 100 read transactions.
//                    For longer transactions use the HW TG.
//
// Company: pgroup @ usc
// Engineer: Sasindu Wijeratne
//*****************************************************************************

`timescale 1ps / 1ps

module example_tb #(
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
  
  // LHS inputs
    input 	wire 										in_LHS_ready_send_top,
    input 	wire 										in_LHS_ready_receive_top,
    input 	wire 	[LEN_FLIT_DATA_LHS-1: 0] 			in_LHS_FLIT_data_top,
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
  output                        wr_rd_complete,

 // LHS outputs
output 	wire 										out_cd_ready_to_receive_LHS_top,
output 	wire 										out_fu_ready_to_send_LHS_top,
output  wire                                        out_cd_avl_receive,
output 	wire 	[LEN_FLIT_DATA_LHS-1: 0] 			out_LHS_FLIT_data_top,

// stat collection
output 	wire 	[1:0]                               stat_occupancy                                                
                                              
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

wrapper_top_cache #(
        .LEN_ADDR(LEN_ADDR),
        .LEN_PROCESSOR_NO(LEN_PROCESSOR_NO),
        .RHS_BURST_LEN(RHS_BURST_LEN),
        .LEN_FLIT_DATA_LHS(LEN_FLIT_DATA_LHS),
        .LEN_MEM_ADDR(APP_ADDR_WIDTH),
        .LEN_MEM_DATA(LEN_DATA_RHS)
    ) inst_wrapper_MC_top (
        .clk                             (clk),
        .mem_clk                         (mem_clk),
        .rst                             (logic_reset),
        .in_LHS_ready_send_top           (in_LHS_ready_send_top),
        .in_LHS_ready_receive_top        (in_LHS_ready_receive_top),
        .in_LHS_FLIT_data_top            (in_LHS_FLIT_data_top),
        .in_RHS_data_top                 (app_rd_data[LEN_DATA_RHS-1:0]),
        .in_RHS_in_data_ready_top        (app_rd_data_valid), 
        .in_RHS_avl_top                  (app_rdy & (app_wdf_rdy|app_rd_data_valid)),
        .out_cd_ready_to_receive_LHS_top (out_cd_ready_to_receive_LHS_top),
        .out_fu_ready_to_send_LHS_top    (out_fu_ready_to_send_LHS_top),
        .out_LHS_FLIT_data_top           (out_LHS_FLIT_data_top),
        .out_cd_avl_receive              (out_cd_avl_receive),
        .out_RHS_addr_top                (app_addr),
        .out_RHS_data_top                (temp_app_wdf_data),
        .out_RHS_wrt_en_top              (app_wdf_wren),
        .out_ready_to_receive_top        (out_ready_to_receive_top),
        .out_RHS_avl_top                 (app_en),
        .out_burst_done                  (app_wdf_end),
        
        .stat_occupancy (stat_occupancy)
    );
    
assign app_cmd = {1'b0,~app_wdf_wren};

endmodule
