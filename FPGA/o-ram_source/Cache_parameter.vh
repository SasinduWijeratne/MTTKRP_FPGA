// This header file includes all preset variables for cache implementation

/*
 * Filename: c:\Users\Andrew\OneDrive\USC\2021 Winter\EE599 FPGA\Project\Code\Cache_parameter.svh
 * Path: c:\Users\Andrew\OneDrive\USC\2021 Winter\EE599 FPGA\Project\Code
 * Created Date: Thursday, March 25th 2021, 10:21:54 am
 * Author: Zhiyu Chen
 * 
 * Copyright (c) 2021 Your Company
 */

`define ADDRESS_LENGTH 32
`define TAG_CNT 12 // number of bits in tag field
`define SET_CNT 2 // number of bits in set field
`define BLOCK_CNT 12 // number of bits in block field
`define BYTE_CNT 6 // number of bits in byte field

`define DATA_WIDTH 512 //For testing DRAM, use smaller depth, eg. 8
`define PID_WIDTH 46
`define DOSA 4 //4
`define ENCODER_WIDTH $clog2(`DOSA)
`define CACHE_DEPTH 4096 //For testing LRU individually, use depth of 1 here