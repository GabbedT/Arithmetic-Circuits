module long_multiplier #(

    /* Number of bits in a word */
    parameter DATA_WIDTH = 8
) (
    input  logic [DATA_WIDTH - 1:0]       operand_A_i,
    input  logic [DATA_WIDTH - 1:0]       operand_B_i,

    output logic [(2 * DATA_WIDTH) - 1:0] result_o
);

//------------//
//  DATAPATH  //
//------------//

    logic [DATA_WIDTH - 1:0][DATA_WIDTH - 1:0] and_product;

        /* Compute the AND between the n-th bit of B and every bit of A 
         * generating DATA_WIDTH product */
        always_comb begin : and_product_generation
            for (int i = 0; i < DATA_WIDTH; ++i) begin 
                for (int j = 0; j < DATA_WIDTH; ++j) begin
                    and_product[i][j] = operand_A_i[j] & operand_B_i[i];
                end              
            end
        end : and_product_generation


    /* Obtained by adding every partial product */
    logic [DATA_WIDTH - 2:0][DATA_WIDTH - 1:0] partial_product;

    /* Carry feeded to the last adder of a row */
    logic [DATA_WIDTH - 2:0] carry_next;

    genvar i;
    generate
        for (i = 0; i < DATA_WIDTH - 1; ++i) begin 
            if (i == 0) begin
                long_multiplier_product_row #(DATA_WIDTH) multiplier_row (
                    .operand_A_i  ( and_product[1][DATA_WIDTH - 1:0]     ),
                    .operand_B_i  ( and_product[0][DATA_WIDTH - 1:1]     ),
                    .prev_carry_i ( 1'b0               ),
                    .result_o     ( partial_product[0][DATA_WIDTH - 1:1] ),
                    .product_bit_o( result_o[1]      ),
                    .carry_o      ( carry_next[0]      ) 
                );
            end else begin
                long_multiplier_product_row #(DATA_WIDTH) multiplier_row (
                    .operand_A_i  ( and_product[i + 1]                       ),
                    .operand_B_i  ( partial_product[i - 1][DATA_WIDTH - 1:1] ),
                    .prev_carry_i ( carry_next[i - 1]                        ),
                    .result_o     ( partial_product[i][DATA_WIDTH - 1:1]     ),
                    .product_bit_o( result_o[i + 1]                          ),
                    .carry_o      ( carry_next[i]                            ) 
                );      
            end
        end
    endgenerate

    assign result_o[(DATA_WIDTH * 2) - 1:DATA_WIDTH] = {carry_next[DATA_WIDTH - 2], partial_product[DATA_WIDTH - 2][DATA_WIDTH - 1:1]};
    assign result_o[0] = and_product[0][0];

endmodule : long_multiplier