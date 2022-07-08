`include "./Cache_parameter.vh"

module DataRAM(
    input wire clk,
    input wire RST,
    input wire peEN_3,
    input wire WrEN,
    input wire memEN_2,
    input wire Rd_Wr,    
    input wire [`BLOCK_CNT-1:0] Index_rd,
    input wire [`SET_CNT+`BLOCK_CNT-1:0] Set_Index_wr,
    input wire [`SET_CNT+`BLOCK_CNT-1:0] Set_Index_repl,
    input wire [`DATA_WIDTH-1:0] Data_pe_in,
    input wire [`DATA_WIDTH-1:0] Data_mem_in,
    output reg [`DATA_WIDTH-1:0] Data_x [`DOSA-1:0],
    output reg [`DATA_WIDTH-1:0] Data_repl
); 
    wire RdEN;
    wire [`SET_CNT-1:0] Set_wr, Set_repl;
    wire [`BLOCK_CNT-1:0] Index_wr, Index_repl;
    reg [`SET_CNT-1:0] Set_repl_2;

    // wire connect to mem module
    reg i_Wr_EN_mem [`DOSA-1:0];
    reg i_Rd_EN_mem [`DOSA-1:0];
    reg [`BLOCK_CNT-1:0] i_Rd_addr [`DOSA-1:0];
    reg [`BLOCK_CNT-1:0] i_Wr_addr [`DOSA-1:0];
    reg [`DATA_WIDTH-1:0] i_Wr_data [`DOSA-1:0];
    reg [`DATA_WIDTH-1:0] o_Rd_data [`DOSA-1:0];

    reg memEN_3;
    reg RdEN_2;

    integer j, k;

    genvar i;

    generate
        for(i=0;i<`DOSA;i=i+1)begin
            DRAM Data_RAM_i (.clka(clk),
                                      .ena(i_Wr_EN_mem[i]),
                                      .wea(i_Wr_EN_mem[i]),
                                      .addra(i_Wr_addr[i]),
                                      .dina(i_Wr_data[i]),
                                      .clkb(clk),
                                      .enb(i_Rd_EN_mem[i]),
                                      .addrb(i_Rd_addr[i]),
                                      .doutb(o_Rd_data[i])
            );

        end

    endgenerate

    assign RdEN = Rd_Wr ? 1 : 0;
    assign Set_wr = Set_Index_wr [`SET_CNT+`BLOCK_CNT-1:`BLOCK_CNT];
    assign Index_wr = Set_Index_wr [`BLOCK_CNT-1:0];
    assign Set_repl = Set_Index_repl [`SET_CNT+`BLOCK_CNT-1:`BLOCK_CNT];
    assign Index_repl = Set_Index_repl [`BLOCK_CNT-1:0];

    always_comb begin
        if(memEN_2==1)begin
            for(k=0;k<`DOSA;k=k+1)begin
                if(k==Set_repl)begin
                    i_Wr_EN_mem[k] = 1;
                    i_Rd_EN_mem[k] = 1;
                    i_Rd_addr[k] = Index_repl;
                    i_Wr_addr[k] = Index_repl;
                    i_Wr_data[k] = Data_mem_in;
                end
                else begin
                    i_Wr_EN_mem[k] = 0;
                    i_Rd_EN_mem[k] = 0;
                    i_Rd_addr[k] = `BLOCK_CNT'b0;
                    i_Wr_addr[k] = `BLOCK_CNT'b0;
                    i_Wr_data[k] = `DATA_WIDTH'b0;
                end
            end
        end
        else begin //memEN_2==0
            if(peEN_3==1)begin
                if(RdEN==1)begin
                    for(k=0; k<`DOSA; k=k+1)begin
                        i_Rd_EN_mem[k] = 1;
                        i_Rd_addr[k] = Index_rd;
                    end
                end
                else begin //RdEN==0
                    for(k=0;k<`DOSA;k=k+1)begin
                        i_Rd_EN_mem[k] = 0;
                    end
                end
                if(WrEN==1)begin
                    for(k=0;k<`DOSA;k=k+1)begin
                        if(k==Set_wr)begin
                            i_Wr_EN_mem[k] = 1;
                            i_Wr_addr[k] = Index_wr;
                            i_Wr_data[k] = Data_pe_in;
                        end
                        else begin //k!=Set_wr
                            i_Wr_EN_mem[k] = 0;
                        end
                    end
                end
                else begin //WrEN==0
                    for(k=0;k<`DOSA;k=k+1)begin
                        i_Wr_EN_mem[k] = 0;
                    end
                end
            end
            else begin //peEN_3==0
                for(k=0;k<`DOSA;k=k+1)begin
                    i_Rd_EN_mem[k] = 0;
                    i_Wr_EN_mem[k] = 0;
                end
            end
        end
        // Read data all happens with one clock delay
        if(memEN_3==1)begin
            for(k=0;k<`DOSA;k++)begin
                if(k==Set_repl_2)begin
                    Data_repl = o_Rd_data[k]; 
                end
                else begin
                    Data_repl = `DATA_WIDTH'b0; // aviod latch, set value to 0
                end
            end
        end
        else begin
            Data_repl = `DATA_WIDTH'b0; // aviod latch, set value to 0
        end

        if(RdEN_2==1)begin
            for(k=0;k<`DOSA;k++)begin
                Data_x[k] = o_Rd_data[k];
            end
        end
        else begin
            for(k=0;k<`DOSA;k++)begin
                Data_x[k] = `DATA_WIDTH'b0; // aviod latch, set value to 0
            end
        end
    
    end

    always@(posedge clk)begin
        if(RST)begin
            memEN_3 <= 0;
            RdEN_2 <= 0;
            Set_repl_2 <= 0;
            // for(j=0;j<`DOSA;j=j+1)begin
            //     i_Wr_EN_mem[j] = 0;
            //     i_Rd_EN_mem[j] = 0;
            // end
        end
        else begin
            memEN_3 <= memEN_2;
            RdEN_2 <= RdEN;
            Set_repl_2 <= Set_repl;
        end
    end


endmodule