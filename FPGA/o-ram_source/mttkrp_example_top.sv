

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
//  /   /         Filename           : example_top.sv
// /___/   /\     Date Last Modified : $Date: 2014/09/03 $
// \   \  /  \    Date Created       : Thu Apr 18 2013
//  \___\/\___\
//
// Device           : UltraScale
// Design Name      : DDR4_SDRAM
// Purpose          :
//                    Top-level  module. This module serves both as an example,
//                    and allows the user to synthesize a self-contained
//                    design, which they can be used to test their hardware.
//                    In addition to the memory controller,
//                    the module instantiates:
//                      1. Synthesizable testbench - used to model
//                      user's backend logic and generate different
//                      traffic patterns
//
// Company: pgroup @ usc
// Engineer: Sasindu Wijeratne
//*****************************************************************************
`ifdef MODEL_TECH
    `define SIMULATION_MODE
`elsif INCA
    `define SIMULATION_MODE
`elsif VCS
    `define SIMULATION_MODE
`elsif XILINX_SIMULATOR
    `define SIMULATION_MODE
`elsif _VCP
    `define SIMULATION_MODE
`endif


`timescale 1ps/1ps
module mttkrp_example_top #
  (
  
parameter 	LEN_ADDR 			=	35,
parameter 	LEN_PROCESSOR_NO 	= 	 7,
parameter   LEN_SLOT_ID         =    7,
parameter 	RHS_BURST_LEN 		= 	 4,
parameter 	LEN_FLIT_DATA_LHS 	= 	608,	
  
    parameter nCK_PER_CLK           = 4,   // This parameter is controllerwise
    parameter         APP_DATA_WIDTH          = 512, // This parameter is controllerwise
    parameter         APP_MASK_WIDTH          = 64,  // This parameter is controllerwise
  `ifdef SIMULATION_MODE
    parameter SIMULATION            = "TRUE" 
  `else
    parameter SIMULATION            = "FALSE"
  `endif

  )
   (
    input                 sys_rst, //Common port for all controllers
    input                 logic_reset,
    output                ref_clk,

    output                  c0_init_calib_complete,
//    output                  c0_data_compare_error,
    input                   c0_sys_clk_p,
    input                   c0_sys_clk_n,
    output                c0_ddr4_parity,   
    
    output                  c0_ddr4_act_n,
    output [16:0]            c0_ddr4_adr,
    output [1:0]            c0_ddr4_ba,
    output [1:0]            c0_ddr4_bg,
    output [0:0]            c0_ddr4_cke,
    output [0:0]            c0_ddr4_odt,
    output [0:0]            c0_ddr4_cs_n,
    output [0:0]                 c0_ddr4_ck_t,
    output [0:0]                c0_ddr4_ck_c,
    output                  c0_ddr4_reset_n,
    inout  [7:0]            c0_ddr4_dm_dbi_n,
    inout  [63:0]            c0_ddr4_dq,
    inout  [7:0]            c0_ddr4_dqs_t,
    inout  [7:0]            c0_ddr4_dqs_c
    );


  localparam  APP_ADDR_WIDTH = 30;
  localparam  MEM_ADDR_ORDER = "ROW_COLUMN_BANK";
  localparam DBG_WR_STS_WIDTH      = 32;
  localparam DBG_RD_STS_WIDTH      = 32;
  localparam ECC                   = "OFF";





  wire [APP_ADDR_WIDTH-1:0]            c0_ddr4_app_addr;
  wire [2:0]            c0_ddr4_app_cmd;
  wire                  c0_ddr4_app_en;
  wire [APP_DATA_WIDTH-1:0]            c0_ddr4_app_wdf_data;
  wire                  c0_ddr4_app_wdf_end;
  wire [APP_MASK_WIDTH-1:0]            c0_ddr4_app_wdf_mask;
  wire                  c0_ddr4_app_wdf_wren;
  wire [APP_DATA_WIDTH-1:0]            c0_ddr4_app_rd_data;
  wire                  c0_ddr4_app_rd_data_end;
  wire                  c0_ddr4_app_rd_data_valid;
  wire                  c0_ddr4_app_rdy;
  wire                  c0_ddr4_app_wdf_rdy;
  wire                  c0_ddr4_clk;
  wire                  c0_ddr4_rst;
  wire                  dbg_clk;
  wire                  c0_wr_rd_complete;



  //HW TG VIO signals
  wire [3:0]                           vio_tg_status_state;
  wire                                 vio_tg_status_err_bit_valid;
  wire [APP_DATA_WIDTH-1:0]            vio_tg_status_err_bit;
  wire [31:0]                          vio_tg_status_err_cnt;
  wire [APP_ADDR_WIDTH-1:0]            vio_tg_status_err_addr;
  wire                                 vio_tg_status_exp_bit_valid;
  wire [APP_DATA_WIDTH-1:0]            vio_tg_status_exp_bit;
  wire                                 vio_tg_status_read_bit_valid;
  wire [APP_DATA_WIDTH-1:0]            vio_tg_status_read_bit;
  wire                                 vio_tg_status_first_err_bit_valid;

  wire [APP_DATA_WIDTH-1:0]            vio_tg_status_first_err_bit;
  wire [APP_ADDR_WIDTH-1:0]            vio_tg_status_first_err_addr;
  wire                                 vio_tg_status_first_exp_bit_valid;
  wire [APP_DATA_WIDTH-1:0]            vio_tg_status_first_exp_bit;
  wire                                 vio_tg_status_first_read_bit_valid;
  wire [APP_DATA_WIDTH-1:0]            vio_tg_status_first_read_bit;
  wire                                 vio_tg_status_err_bit_sticky_valid;
  wire [APP_DATA_WIDTH-1:0]            vio_tg_status_err_bit_sticky;
  wire [31:0]                          vio_tg_status_err_cnt_sticky;
  wire                                 vio_tg_status_err_type_valid;
  wire                                 vio_tg_status_err_type;
  wire                                 vio_tg_status_wr_done;
  wire                                 vio_tg_status_done;
  wire                                 vio_tg_status_watch_dog_hang;
  wire                                 tg_ila_debug;

  // Debug Bus
  wire [511:0]                         dbg_bus;   
  
  wire                                  addn_ui_clkout1;     

wire 										out_cd_ready_to_receive_LHS_inter;



wire c0_ddr4_reset_n_int;
  assign c0_ddr4_reset_n = c0_ddr4_reset_n_int;

//***************************************************************************
// The User design is instantiated below. The memory interface ports are
// connected to the top-level and the application interface ports are
// connected to the traffic generator module. This provides a reference
// for connecting the memory controller to system.
//***************************************************************************

//wire board_clk_p;
//wire board_clk_n;

 assign ref_clk = addn_ui_clkout1;	
//BUFGP BUFGP2 (board_clk_n, c0_sys_clk_n);

  // user design top is one instance for all controllers
ddr4_0 u_ddr4_0
  (
   .sys_rst           (sys_rst),

   .c0_sys_clk_p                   (c0_sys_clk_p),
   .c0_sys_clk_n                   (c0_sys_clk_n),
   .c0_init_calib_complete (c0_init_calib_complete),
   .c0_ddr4_act_n          (c0_ddr4_act_n),
   .c0_ddr4_adr            (c0_ddr4_adr),
   .c0_ddr4_ba             (c0_ddr4_ba),
   .c0_ddr4_bg             (c0_ddr4_bg),
   .c0_ddr4_cke            (c0_ddr4_cke),
   .c0_ddr4_odt            (c0_ddr4_odt),
   .c0_ddr4_cs_n           (c0_ddr4_cs_n),
   .c0_ddr4_ck_t           (c0_ddr4_ck_t),
   .c0_ddr4_ck_c           (c0_ddr4_ck_c),
   .c0_ddr4_reset_n        (c0_ddr4_reset_n_int),
   .c0_ddr4_parity                        (c0_ddr4_parity),

//   .c0_ddr4_dm_dbi_n       (c0_ddr4_dm_dbi_n),
   .c0_ddr4_dq             (c0_ddr4_dq),
   .c0_ddr4_dqs_c          (c0_ddr4_dqs_c),
   .c0_ddr4_dqs_t          (c0_ddr4_dqs_t),

   .c0_ddr4_ui_clk                (c0_ddr4_clk),
   .c0_ddr4_ui_clk_sync_rst       (c0_ddr4_rst),
   .dbg_clk                                    (dbg_clk),

   .c0_ddr4_app_addr              (c0_ddr4_app_addr),
   .c0_ddr4_app_cmd               (c0_ddr4_app_cmd),
   .c0_ddr4_app_en                (c0_ddr4_app_en),
   .c0_ddr4_app_hi_pri            (1'b0),
   .c0_ddr4_app_wdf_data          (c0_ddr4_app_wdf_data),
   .c0_ddr4_app_wdf_end           (c0_ddr4_app_wdf_end),
//   .c0_ddr4_app_wdf_mask          (c0_ddr4_app_wdf_mask),
   .c0_ddr4_app_wdf_wren          (c0_ddr4_app_wdf_wren),
   .c0_ddr4_app_rd_data           (c0_ddr4_app_rd_data),
   .c0_ddr4_app_rd_data_end       (c0_ddr4_app_rd_data_end),
   .c0_ddr4_app_rd_data_valid     (c0_ddr4_app_rd_data_valid),
   .c0_ddr4_app_rdy               (c0_ddr4_app_rdy),
   .c0_ddr4_app_wdf_rdy           (c0_ddr4_app_wdf_rdy),
   .addn_ui_clkout1               (addn_ui_clkout1),
  
  // Debug Port
  .dbg_bus         (dbg_bus)                                             

  );

//***************************************************************************
// The example testbench module instantiated below drives traffic (patterns)
// on the application interface of the memory controller
//***************************************************************************
// In DDR4, there are two test generators (TG) available for user to select:
//  1) Simple Test Generator (STG)
//  2) Advanced Test Generator (ATG)
// 

//assign out_cd_ready_to_receive_LHS_top = out_cd_ready_to_receive_LHS_inter & c0_init_calib_complete;

    mttkrp_example_tb #
      (
       .SIMULATION     (SIMULATION),
       .APP_DATA_WIDTH (APP_DATA_WIDTH),
       .APP_ADDR_WIDTH (APP_ADDR_WIDTH),
       .LEN_SLOT_ID    (LEN_SLOT_ID),
       .MEM_ADDR_ORDER (MEM_ADDR_ORDER)
       )
      u_example_tb
        (
         .clk                                     (addn_ui_clkout1),
         .mem_clk                                 (c0_ddr4_clk),
         .rst                                     (c0_ddr4_rst),
         .logic_reset                             (logic_reset),
         .app_rdy                                 (c0_ddr4_app_rdy),
         .init_calib_complete                     (c0_init_calib_complete),
         .app_rd_data_valid                       (c0_ddr4_app_rd_data_valid),
         .app_rd_data                             (c0_ddr4_app_rd_data),
         .app_wdf_rdy                             (c0_ddr4_app_wdf_rdy),
         .app_en                                  (c0_ddr4_app_en),
         .app_cmd                                 (c0_ddr4_app_cmd),
         .app_addr                                (c0_ddr4_app_addr),
         .app_wdf_wren                            (c0_ddr4_app_wdf_wren),
         .app_wdf_end                             (c0_ddr4_app_wdf_end),
         .app_wdf_mask                            (c0_ddr4_app_wdf_mask),
         .app_wdf_data                            (c0_ddr4_app_wdf_data),
         .compare_error                           (c0_data_compare_error),
         .wr_rd_complete                          (c0_wr_rd_complete)

      );
endmodule





































