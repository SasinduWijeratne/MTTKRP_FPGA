`include "./Cache_parameter.vh"

module DRAM(
    input wire clka,
    input wire ena,
    input wire wea,
    input wire [`BLOCK_CNT-1:0] addra,
    input wire [`DATA_WIDTH-1:0] dina,
    input wire clkb,
    input wire enb,
    input wire [`BLOCK_CNT-1:0] addrb,
    output reg [`DATA_WIDTH-1:0] doutb
);
    (*rom_style="block" *) reg [`DATA_WIDTH-1:0] mem [`CACHE_DEPTH-1:0];

    always@(posedge clka)begin
        if(enb)
          doutb <= mem[addrb];
        if(wea)
          mem[addra] <= dina;
    end

//    initial begin
//        $display("Loading DRAM");
//        $readmemh("hex_DRAM_test_0.mem",mem);
//    end

endmodule
