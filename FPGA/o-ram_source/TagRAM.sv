`include "./Cache_parameter.vh"

module TagRAM(
    input wire clk,
    input wire peEN_1,
    input wire [`BLOCK_CNT-1:0] Index_pe,

    input wire memEN_2,
    input wire [`SET_CNT-1:0] Set_repl,
    input wire [`BLOCK_CNT-1:0] Index_mem,
    input wire [`TAG_CNT-1:0] Tag_upd,

    output reg [`TAG_CNT:0] Tag_x [`DOSA-1:0], // {Valid,Tag}. `DOSA Number of Tags pull out from Tag_RAM.
    output reg [`TAG_CNT:0] Tag_repl_valid
);

    wire [`TAG_CNT:0] Tag_upd_valid;

    (*rom_style="block" *) reg [`TAG_CNT:0] Tag_RAM [`CACHE_DEPTH*`DOSA-1:0]; // Width = `TAG_CNT + 1 -> one bit Valid bit
    
    integer i,j,k;

    assign Tag_upd_valid = {1'b1,Tag_upd}; // 1 concatenate with tag from memory

    always@(posedge clk)begin
        if(memEN_2==1)begin
            Tag_repl_valid <= Tag_RAM[Set_repl*`CACHE_DEPTH + Index_mem];
            Tag_RAM[Set_repl*`CACHE_DEPTH + Index_mem] <= Tag_upd_valid;
        end
        else begin // memEN==0
            if(peEN_1==1)begin
                for(k=0; k<`DOSA; k=k+1)begin
                    Tag_x[k] <= Tag_RAM[k*`CACHE_DEPTH + Index_pe];
                end
            end
            else begin // peEN==1
                // do nothing
            end
        end
        // Note: memEN&&peEN==1 should be invalid
    end
    
    // initial begin
    //     $display("Loading TagRAM");
    //     $readmemb("bin_TagRAM_test_1.mem",Tag_RAM);
    // end

endmodule

