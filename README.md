# Accelerating Mode Agnostic Sparse MTTKRP on FPGA

A novel FPGA accelerator for sparse MTTKRP (spMTTKRP) to maximally exploit the spatial and temporal locality of spMTTKRP by a parallel pipeline architecture. We also introduce FLYCOO, a novel mode-agnostic tensor format for FPGA acceleration. FLYCOO supports on-the-fly memory layout remapping to avoid storing intermediate values in the external memory.

## Folder Structure

    ├── Cycle_Estimator           # A cycle estimator for Design Space Exploration
    ├── FLYCOO                    # Converts sparse tensors in Coordinates (COO) format to FLYCOO
    ├── FPGA                      # Verilog source codes for the implementation
    │   ├── ip                    
    │   ├── src                                   
    ├── LICENSE
    └── README.md

## Installation
1. FPGA Project setup is included in FPGA Folder
2. FLYCOO folder contains the source codes for the conversion of the datasets to proposed format

## Datasets
We use FROSTT datasets (http://frostt.io/tensors/) for evaluation.

## Sample Experiments to conduct
Step 1: Generate FLYCOO format tensor.
    - Use the scripts in the FLYCOO with any FROSTT dataset (instructions are on the readme in FLYCOO Folder)
    
2. Place and Route results of FPGA design
    - After setting up the FPGA design on Vivado 2020.2 according to the instructions in the readme inside FPGA folder, run "Implementation" on Vivado software (instructions are on the readme in FPGA folder)


## License
[MIT](https://choosealicense.com/licenses/mit/)
