# FLYCOO: New Tensor Format
Script that reorders a tensor stored in COO format according to semi_alto score.
The mode_axis indicates the mode that is disregarded in the semi_alto score computation.
Again, the semi_alto score is computed to reorder the rows but is not appended to the 
resulting tensor. Note: the output file is currently hardcoded and depends on the 
input_file_path. For examples on how to run, check out the script semi_alto.sh.

## Usage:
    python3 semi_alto.py <input_file> <num_dimensions> <mode_axis>

## requirements:
    - python3
    - pyspark