`include "./Cache_parameter.vh"

module LRU(
    input wire clk,
    input wire RST,
    input wire memEN,
    input wire peEN_3,
    input wire Rd_Wr,
    input wire [`DOSA-1:0] hit_x,
    input wire HIT,
    input wire [`BLOCK_CNT-1:0] Index_pe,
    input wire [`SET_CNT+`BLOCK_CNT-1:0] Set_Index_mem,
    
    output reg [`SET_CNT*2+2-1:0] Least_used_lru
);

    wire [`BLOCK_CNT-1:0] Index_mem;
    wire [`SET_CNT-1:0] Set_origin_mem;
    wire [`DOSA-1:0] Shift_index; // indicating which Tags in specific column (by index) of LRU need to be shift down
    wire [`SET_CNT-1:0] ONE_concat, ZERO_concat;
    reg [`SET_CNT-1:0] j_val;

    reg [`BLOCK_CNT-1:0] Index_pe_2;
    reg [`DOSA-1:0] hit_x_2;
    reg HIT_2;
    reg Rd_Wr_2;
    reg [`DOSA-1:0] Shift_index_2;
    reg peEN_4;

    (*rom_style="block" *) reg [`SET_CNT*2+2-1:0] LRU_RAM [`CACHE_DEPTH-1:0][`DOSA-1:0]; // {Valid, Dirty, Set}[3:0]

    integer i,j;
    genvar k;

    generate
        for(k=0;k<`SET_CNT;k=k+1)begin
            assign ONE_concat[k] = 1'b1;
            assign ZERO_concat[k] = 1'b0;
        end
    endgenerate

    assign Index_mem = Set_Index_mem[`BLOCK_CNT-1 : 0];
    assign Set_origin_mem = Set_Index_mem[`SET_CNT+`BLOCK_CNT-1 : `BLOCK_CNT];
    assign Shift_index = hit_x - 1; // 1 in Shift_index means corresponding column need to be shift down

    always@(posedge clk)begin
        if(RST==1)begin
            peEN_4 <= 0;
            for(i=0; i<`CACHE_DEPTH; i=i+1)begin
                for(j=0; j<`DOSA; j++)begin
                    j_val = j;
                    LRU_RAM[i][j] <= {2'b00,j_val,ZERO_concat}; // clear Valid and Dirty bits when reset
                end
            end
        end
        else begin

            Index_pe_2 <= Index_pe;
            hit_x_2 <= hit_x;
            HIT_2 <= HIT;
            Rd_Wr_2 <= Rd_Wr;
            Shift_index_2 <= Shift_index;
            peEN_4 <= peEN_3;

            if(memEN==1)begin
                Least_used_lru <= LRU_RAM[Index_mem][`DOSA-1];
                for(i=0; i<`DOSA-1;i=i+1)begin
                    LRU_RAM[Index_mem][i+1] <= LRU_RAM[Index_mem][i];
                end
                LRU_RAM[Index_mem][0] <= (LRU_RAM[Index_mem][`DOSA-1] & {1'b1, 1'b1, ONE_concat, ZERO_concat}) | {1'b1,1'b0, ZERO_concat, Set_origin_mem}; // make valid 1, change the Set_origin_mem value to the new incoming set value in address
            end
            else begin // memEN==0
                if(peEN_4==1)begin
                    if(HIT_2==1)begin // All rows on top of the matched row need to be shift down. Matched row need to be put on top
                        for(i=0; i<`DOSA-1; i=i+1)begin
                            if(Shift_index_2[i]==1)begin
                                LRU_RAM[Index_pe_2][i+1] <= LRU_RAM[Index_pe_2][i]; // All rows on top shift down 
                            end
                            else begin // Shift_index==0;
                                if(hit_x_2[i]==1)begin
                                    if(Rd_Wr_2==0)begin // pe Write, change dirty bit to 1
                                        LRU_RAM[Index_pe_2][0] <= LRU_RAM[Index_pe_2][i] | {1'b0,1'b1, ZERO_concat, ZERO_concat}; 
                                    end
                                    else begin // pe read, keep dirty bit 0
                                        LRU_RAM[Index_pe_2][0] <= LRU_RAM[Index_pe_2][i]; 
                                    end
                                end
                                else begin // rows under the matched one remains the same
                                    // DO nothing
                                end
                            end
                        end
                    end
                    else begin// Hit==0, do nothing in                                           
                    end
                end
                else begin // peEN_3==0 && memEN==0
                    // DO nothing
                end
            end
        end
    end

endmodule


