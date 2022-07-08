`include "./Cache_parameter.vh"

module Tag_comparator( // in second stage of pe pipeline
    input wire clk,
    input wire RST,
    input wire peEN_2,
    input wire [`TAG_CNT:0] Tag_x [`DOSA-1:0],
    input wire [`TAG_CNT-1:0] Tag_in,
    output reg [`DOSA-1:0] hit_x,
    output reg [`ENCODER_WIDTH-1:0] hit_encode,
    output reg HIT
);
    wire [`TAG_CNT:0] Tag_in_valid;
    wire [`DOSA-1:0] hitx;
    wire [`ENCODER_WIDTH-1:0] hit_enc;
    wire [`DOSA-1:0] ZERO;

    genvar i;
    integer j, k; 

    assign Tag_in_valid = {1'b1, Tag_in};
    
    generate // equal number of comparators to the number of ways we have
        for(i=0; i<`DOSA; i=i+1) begin
            assign hitx[i] = (Tag_x[i] == Tag_in_valid) ? 1 : 0;
            assign ZERO[i] = 1'b0;
        end
    endgenerate

    onehot_enc encoder(.in(hitx),
                       .out(hit_enc)
    );

    always@(posedge clk)begin
        if(RST==1)begin
            for(j=0; j<`DOSA; j=j+1)begin
                hit_x[j] <= 0;
            end
            HIT <= 0;
        end
        else begin
            for(k=0; k<`DOSA; k=k+1)begin
                if(peEN_2)
                    hit_x[k] <= hitx[k];
                else
                    hit_x[k] <= ZERO;
            end
            hit_encode <= hit_enc;
            HIT <= peEN_2 ? (|hitx ? 1 : 0) : 0;
        end
    end

endmodule

module onehot_enc #(parameter WIDTH=`DOSA) (
    input logic [WIDTH-1:0] in,
    output logic [$clog2(WIDTH)-1:0] out
);
    always_comb begin
        out = 0;
        for (int i = 0; i < WIDTH; i++) begin
            if (in[i])
                out = i;
        end
    end

endmodule