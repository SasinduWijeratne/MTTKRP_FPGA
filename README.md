# Accelerating Mode Agnostic Sparse MTTKRP on FPGA

A novel FPGA accelerator for sparse MTTKRP (spMTTKRP) to maximally exploit the spatial and temporal locality of spMTTKRP by a parallel pipeline architecture. We also introduce FLYCOO, a novel mode-agnostic tensor format for FPGA acceleration. FLYCOO supports on-the-fly memory layout remapping to avoid storing intermediate values in the external memory.

## Folder Structure
| <br />
- Cycle_Estimator: A cycle estimator for Design Space Exploration <br />
| <br />
-FLYCOO: Converts sparse tensors in Coordinates (COO) format to FLYCOO <br />
| <br />
-FPGA: Verilog source codes for the implementation <br />
--ip <br />
--src <br />

## License
[MIT](https://choosealicense.com/licenses/mit/)
