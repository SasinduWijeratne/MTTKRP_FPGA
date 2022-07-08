`include "./Cache_parameter.vh"

module Data_Select(  // in third stage of pe pipeline
    input wire [`DATA_WIDTH-1:0] Data_x [`DOSA-1:0],
    input wire HIT,
    input wire Rd_Wr, // Address_pe[32], 1 for Rd, 0 for Wr
    input wire [`ENCODER_WIDTH-1:0] hit_encode,
    output wire [`DATA_WIDTH-1:0] Data_pe_out
);

    wire RdEN;

    assign RdEN = HIT && Rd_Wr;
    assign Data_pe_out =  RdEN ? Data_x[hit_encode] : `DATA_WIDTH'b0;

endmodule