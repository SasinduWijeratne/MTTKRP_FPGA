# FPGA
This includes all the hardware design files of our implementation. The design is verfied on Xilinx Alveo U250 FPGA. This work is developed with Xilinx Vivado 2020.2.

## requirements:
#### Software
    - Xilinx Vivado 2020.2
#### FPGA Device
    - Alveo U250 Data Center Accelerator Card
#### Language
    - Verilig + System Verilog

## Setting up the project
- Include the source files in src folder as sources
- Include IPs in the ip folder as external IPs to the project
        - The IPs contains FIFOs and external memory interface IPs

#### Top Module name
    - mttkrp_example_top

#### Configuring the 3rd party IPs

##### Memory Interface IP
    - IP Name: DDR4 SDRAM
    - Instance Name: ddr4_0
    - Basic: Memory Device Interface Speed (ps): 833
    - Basic: PHY clock frequency ratio: (4:1) 
    - Basic: Configuration: RDIMMS
    - Memory Part: MTA18ASF2G72PZ-2G3

## Module Structure (refer to the figures)

![Screenshot from 2022-05-29 16-54-18](https://user-images.githubusercontent.com/54261529/170896512-627f91be-3836-4d5f-aae0-ff0f47b9c167.png)
![Screenshot from 2022-05-29 16-54-39](https://user-images.githubusercontent.com/54261529/170896515-468e5851-962f-46af-8fa6-7f66b672d8d5.png)
