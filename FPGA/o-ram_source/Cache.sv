`include "./Cache_parameter.vh"

module Cache(
    // in/out ports to PE
    input wire clk,
    input wire RST,
    input wire i_peEN,
    input wire [`PID_WIDTH-1:0] PID_pe_in, // send PID + Address to Inside
    input wire [`DATA_WIDTH-1:0] Data_pe_in,
    input wire [`ADDRESS_LENGTH:0] Address_pe, // {rd/wr,address}
    output reg [`PID_WIDTH-1:0] PID_pe_out, // receive PID + Address to outside
    output reg [`DATA_WIDTH-1:0] Data_pe_out,
    output reg HIT_pe_out, // HIT signal passing to PE. 1 for HIT, 0 for MISS
    output reg MEM_pe_forward, // indicating current Data_pe_out and PID_pe_out are valid data and PID from memory
    // in/out ports to MEM
    input wire i_memEN,
    input wire [`PID_WIDTH-1:0] PID_mem_in, // send PID + Address to Inside
    input wire [`DATA_WIDTH-1:0] Data_mem_in,
    input wire [`ADDRESS_LENGTH-1:0] Address_mem_in,
    output wire [`PID_WIDTH-1:0] PID_mem_out, // receive PID + Address to outside
    output wire [`DATA_WIDTH-1:0] Data_mem_out,
    output wire [`ADDRESS_LENGTH-1:0] Address_mem_out,
    output wire Flush_mem_out, // Indicating if a substituted data is flushing back to memory (if dirty then flush)
    output wire cache_miss,
    output wire o_memEN // Indicating there are instructions in the MEM pipeline. If o_memEN is 1, then pe should not assert peEN
);

    /* PE pipeline signals */
    wire peEN;
    // Stage I:
    wire [`TAG_CNT-1:0] Tag_pe_1; 
    wire [`SET_CNT-1:0] Set_pe_1;
    wire [`BLOCK_CNT-1:0] Block_pe_1;
    wire [`DATA_WIDTH-1:0] Data_pe_1;
    wire Rd_Wr_pe_1;
    wire peEN_1;
    wire PID_pe_1;
    // Stage II:
    reg [`TAG_CNT-1:0] Tag_pe_2; 
    reg [`SET_CNT-1:0] Set_pe_2;
    reg [`BLOCK_CNT-1:0] Block_pe_2;
    reg [`TAG_CNT:0] Tag_x_pe_2 [`DOSA-1:0]; // {Valid, Tag}
    reg [`DATA_WIDTH-1:0] Data_pe_2;
    reg Rd_Wr_pe_2;
    reg peEN_2;
    reg PID_pe_2;
    // Stage III:
    reg [`TAG_CNT-1:0] Tag_pe_3; 
    reg [`SET_CNT-1:0] Set_pe_3;
    reg [`BLOCK_CNT-1:0] Block_pe_3;
    reg [`SET_CNT+`BLOCK_CNT-1:0] Set_block_pe_3;
    reg [`DATA_WIDTH-1:0] Data_pe_3;
    wire [`DOSA-1:0] hit_x_pe_3;
    wire [`ENCODER_WIDTH-1:0] hit_encode_pe_3;
    wire HIT_pe_3;
    reg Rd_Wr_pe_3;
    wire WrEN_pe_3;
    reg peEN_3;
    reg PID_pe_3;
    // Stage IV:
    wire [`DATA_WIDTH-1:0] DataRAM_data_out;
    wire [`DATA_WIDTH-1:0] Data_x_pe_4 [`DOSA-1:0];
    reg [`DOSA-1:0] hit_x_pe_4;
    reg HIT_pe_4;
    reg Rd_Wr_pe_4;
    reg [`ENCODER_WIDTH-1:0] hit_encode_pe_4;
    reg peEN_4;
    reg PID_pe_4;

    /* MEM pipeline signals */
    wire memEN;
    // Stage I:
    wire memEN_1;
    wire [`TAG_CNT-1:0] Tag_upd_mem_1;
    wire [`SET_CNT-1:0] Set_mem_1;    
    wire [`BLOCK_CNT-1:0] Block_mem_1;
    wire [`SET_CNT+`BLOCK_CNT-1:0] Set_Block_mem_1;
    wire [`DATA_WIDTH-1:0] Data_upd_mem_1;
    // Stage II:
    reg memEN_2;
    reg [`TAG_CNT-1:0] Tag_upd_mem_2;
    wire [`SET_CNT*2+2-1:0] Least_used_lru_mem_2;
    wire [`SET_CNT-1:0] Set_repl_mem_2;
    wire [`SET_CNT-1:0] Set_origin_mem_2;
    reg [`BLOCK_CNT-1:0] Block_mem_2;
    wire [`SET_CNT+`BLOCK_CNT-1:0] Set_block_repl_mem_2;
    reg [`DATA_WIDTH-1:0] Data_upd_mem_2;
    wire Flush_mem_2;
    // Stage III:
    reg memEN_3;
    wire [`TAG_CNT-1:0] Tag_repl_mem_3;
    wire [`TAG_CNT:0] Tag_repl_valid_mem_3;
    wire [`ADDRESS_LENGTH-1:0] Address_repl_mem_3;
    wire [`DATA_WIDTH-1:0] Data_repl_mem_3;
    reg [`SET_CNT-1:0] Set_origin_mem_3;
    reg [`BLOCK_CNT-1:0] Block_mem_3;
    reg Flush_mem_3;
 
    /* PE pipeline signals */
    assign peEN = peEN_1 | peEN_2 | peEN_3 | peEN_4 ? 1 : 0; // once the fifo provide peEN, it should last for 4 clocks internally
    // Stage I:
    assign peEN_1 = i_peEN ? 1 : 0;
    assign PID_pe_1 = PID_pe_in;
    assign Tag_pe_1 = Address_pe[`ADDRESS_LENGTH-1 : `BYTE_CNT+`BLOCK_CNT+`SET_CNT];
    assign Set_pe_1 = Address_pe[`BYTE_CNT+`BLOCK_CNT+`SET_CNT-1 : `BYTE_CNT+`BLOCK_CNT];
    assign Block_pe_1 = Address_pe[`BYTE_CNT+`BLOCK_CNT-1 : `BYTE_CNT];
    assign Data_pe_1 = Data_pe_in;
    assign Rd_Wr_pe_1 = Address_pe[`ADDRESS_LENGTH];
    assign Data_upd_mem_1 = Data_mem_in;
    // Stage II:
    // Stage III:
    assign Set_block_pe_3 = {hit_encode_pe_3, Block_pe_3}; // Set and block field for Wr instruction. Set is the matched set value in cache
    assign WrEN_pe_3 = (!Rd_Wr_pe_3 && HIT_pe_3) ? 1 : 0; // Is write instruction with HIT, then WrEN=1
    // Stage IV:
    assign HIT_pe_out = (HIT_pe_4 && peEN_4) ? 1 : 0;

    /* MEM pipeline signals */
    assign memEN = memEN_1 | memEN_2 | memEN_3 ? 1 : 0; // once the fifo provide memEN, it should last for 3 clock cycles internally
    assign o_memEN = memEN_1 | memEN_2 | memEN_3 ? 1 : 0;
    // Stage I:
    assign memEN_1 = i_memEN ? 1 : 0;
    assign MEM_pe_forward = memEN_1 ? 1 : 0;
    assign Tag_upd_mem_1 = Address_mem_in[`ADDRESS_LENGTH-1 : `BYTE_CNT+`BLOCK_CNT+`SET_CNT];
    assign Set_mem_1 = Address_pe[`BYTE_CNT+`BLOCK_CNT+`SET_CNT-1 : `BYTE_CNT+`BLOCK_CNT];
    assign Block_mem_1 = Address_mem_in[`BYTE_CNT+`BLOCK_CNT-1 : `BYTE_CNT];
    assign Set_Block_mem_1 = {Set_mem_1, Block_mem_1};
    // Stage II:
    assign Set_repl_mem_2 = Least_used_lru_mem_2[`SET_CNT*2-1:`SET_CNT];
    assign Set_origin_mem_2 = Least_used_lru_mem_2[`SET_CNT-1:0];
    assign Set_block_repl_mem_2 = {Set_repl_mem_2, Block_mem_2};
    assign Flush_mem_2 = Least_used_lru_mem_2[`SET_CNT*2]; // Flush signal depends on dirty bit in LRU
    // Stage III:
    assign Tag_repl_mem_3 = Tag_repl_valid_mem_3[`TAG_CNT-1:0];
    assign Address_repl_mem_3 = {Tag_repl_mem_3, Set_origin_mem_3, Block_mem_3, `BYTE_CNT'b0};
    assign Address_mem_out = Flush_mem_3 ? Address_repl_mem_3 : `ADDRESS_LENGTH'b0; //?
    assign Data_mem_out = Flush_mem_3 ? Data_repl_mem_3 : `DATA_WIDTH'b0; //?
    assign Flush_mem_out = Flush_mem_3 ? 1 : 0;
    assign PID_mem_out = HIT_pe_out ? `PID_WIDTH'b0 : PID_pe_4;
    assign cache_miss = ((~HIT_pe_4) && peEN_4) ? 1 : 0;;

    /* Shared output signals */
    assign Data_pe_out = memEN_1 ? Data_mem_in : HIT_pe_out ? DataRAM_data_out : `DATA_WIDTH'b0;
    assign PID_pe_out = memEN_1 ? PID_mem_in : HIT_pe_out ? PID_pe_4 : `PID_WIDTH'b0;


    always@(posedge clk)begin
        if(RST==1)begin
            peEN_2 <= 0;
            peEN_3 <= 0;
            peEN_4 <= 0;
            memEN_2 <= 0;
            memEN_3 <= 0;
        end
        else begin
            if(memEN==1)begin
                memEN_2 <= memEN_1;
                memEN_3 <= memEN_2;
                Tag_upd_mem_2 <= Tag_upd_mem_1;
                Block_mem_2 <= Block_mem_1;
                Block_mem_3 <= Block_mem_2;
                Data_upd_mem_2 <= Data_upd_mem_1;
                Set_origin_mem_3 <= Set_origin_mem_2;
                Flush_mem_3 <= Flush_mem_2;
            end
            else begin
                if(peEN==1)begin
                    peEN_2 <= peEN_1;
                    peEN_3 <= peEN_2;
                    peEN_4 <= peEN_3;
                    PID_pe_2 <= PID_pe_1;
                    PID_pe_3 <= PID_pe_2;
                    PID_pe_4 <= PID_pe_3;
                    Tag_pe_2 <= Tag_pe_1;
                    Tag_pe_3 <= Tag_pe_2;
                    Set_pe_2 <= Set_pe_1;
                    Set_pe_3 <= Set_pe_2;
                    Block_pe_2 <= Block_pe_1;
                    Block_pe_3 <= Block_pe_2;
                    Data_pe_2 <= Data_pe_1;
                    Data_pe_3 <= Data_pe_2;
                    Rd_Wr_pe_2 <= Rd_Wr_pe_1;
                    Rd_Wr_pe_3 <= Rd_Wr_pe_2;
                    hit_x_pe_4 <= hit_x_pe_3;
                    HIT_pe_4 <= HIT_pe_3;
                    Rd_Wr_pe_4 <= Rd_Wr_pe_3;
                    hit_encode_pe_4 <= hit_encode_pe_3;
                end
            end 
        end
    end

    TagRAM TagRAM_inst(.clk(clk),
                       .peEN_1(peEN_1),
                       .Index_pe(Block_pe_1), // PE stage 1
                       .memEN_2(memEN_2),
                       .Set_repl(Set_repl_mem_2), // MEM stage 2
                       .Index_mem(Block_mem_2), // MEM stage 2
                       .Tag_upd(Tag_upd_mem_2), // MEM stage 2
                       .Tag_x(Tag_x_pe_2), // PE stage 2
                       .Tag_repl_valid(Tag_repl_valid_mem_3) // MEM stage 3
    );

    Tag_comparator Tag_comparator_inst(.clk(clk),
                                       .RST(RST),
                                       .peEN_2(peEN_2),
                                       .Tag_x(Tag_x_pe_2), // PE stage 2
                                       .Tag_in(Tag_pe_2), // PE stage 2
                                       .hit_x(hit_x_pe_3), // PE stage 3
                                       .hit_encode(hit_encode_pe_3), // PE stage 3
                                       .HIT(HIT_pe_3) // PE stage 3

    );

    DataRAM DataRAM_inst(.clk(clk),
                         .RST(RST),
                         .peEN_3(peEN_3),
                         .WrEN(WrEN_pe_3), // PE stage 3
                         .memEN_2(memEN_2),
                         .Rd_Wr(Rd_Wr_pe_3),
                         .Index_rd(Block_pe_3), // PE stage 1
                         .Set_Index_wr(Set_block_pe_3), // PE stage 3
                         .Set_Index_repl(Set_block_repl_mem_2), // MEM stage 2
                         .Data_pe_in(Data_pe_3), // PE stage 3
                         .Data_mem_in(Data_upd_mem_2), // MEM stage 2
                         .Data_x(Data_x_pe_4), // PE stage 2
                         .Data_repl(Data_repl_mem_3) // MEM stage 3, to memory controller
    );

    Data_Select Data_Select_inst(.Data_x(Data_x_pe_4), // PE stage 4
                                 .HIT(HIT_pe_4), // PE stage 4
                                 .Rd_Wr(Rd_Wr_pe_4), // PE stage 4
                                 .hit_encode(hit_encode_pe_4),
                                 .Data_pe_out(DataRAM_data_out) // PE stage 4, to PE
    );

    LRU LRU_inst(.clk(clk),
                 .RST(RST),
                 .memEN(memEN_1),
                 .peEN_3(peEN_3),
                 .Rd_Wr(Rd_Wr_pe_3), // PE stage 3, for dirty bit
                 .hit_x(hit_x_pe_3), // PE stage 3
                 .HIT(HIT_pe_3), // PE stage 3
                 .Index_pe(Block_pe_3), // PE stage 3
                 .Set_Index_mem(Set_Block_mem_1), // MEM stage 1
                 .Least_used_lru(Least_used_lru_mem_2) // MEM stage 2
    );

endmodule


