// MIT License
//
// Copyright (c) 2021 Gabriele Tripi
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// ------------------------------------------------------------------------------------
// ------------------------------------------------------------------------------------
// FILE NAME : pipelined_long_multiplier_stage.sv
// DEPARTMENT : 
// AUTHOR : Gabriele Tripi
// AUTHOR'S EMAIL : tripi.gabriele2002@gmail.com
// ------------------------------------------------------------------------------------
// RELEASE HISTORY
// VERSION : 1.0 
// DESCRIPTION : This module is a stage of the final pipelined multiplier. It is a 
//               modified version of the module in: `long_multiplier.sv`.
// ------------------------------------------------------------------------------------
// PARAMETERS
// NAME              : RANGE : ILLEGAL VALUES 
//-------------------------------------------------------------------------------------
// DATA_WIDTH        :   /   : Not power of 2   
// PRODUCT_PER_STAGE :   /   : Not power of 2
// ------------------------------------------------------------------------------------


module pipelined_long_multiplier_stage #(

    /* Number of bits in a word */
    parameter DATA_WIDTH = 8,

    /* Number of partial products in every stage */
    parameter PRODUCT_PER_STAGE = 4
) (
    input  logic  [DATA_WIDTH - 1:0]        operand_A_i,
    input  logic  [PRODUCT_PER_STAGE - 1:0] operand_B_i,
    input  logic  [DATA_WIDTH - 2:0]        last_partial_prod_i,
    input  logic                            carry_i,

    output logic                            carry_o,
    output logic [DATA_WIDTH - 2:0]         partial_product_o,
    output logic [PRODUCT_PER_STAGE - 1:0]  final_result_bits_o
);

//------------//
//  DATAPATH  //
//------------//

    logic [PRODUCT_PER_STAGE - 1:0][DATA_WIDTH - 1:0] and_product;

        /* Compute the AND between the n-th bit of B and every bit of A 
         * generating DATA_WIDTH product */
        always_comb begin : and_product_generation
            for (int i = 0; i < PRODUCT_PER_STAGE; ++i) begin 
                for (int j = 0; j < DATA_WIDTH; ++j) begin
                    and_product[i][j] = operand_A_i[j] & operand_B_i[i];
                end              
            end
        end : and_product_generation


    /* Obtained by adding every AND product */
    logic [PRODUCT_PER_STAGE - 1:0][DATA_WIDTH - 1:0] partial_product;

    /* Carry feeded to the last adder of a row */
    logic [PRODUCT_PER_STAGE - 1:0] carry_next;

    
    /*
     *  This is the partial product array generation, the modules take as input
     *  two AND product (1 bit multiplication) and the carry of the previous row.
     *  Then output the result has DATA_WIDTH - 1 bits, the `product_bit` which
     *  is the LSB of the result, that bit will be the n-th bit of the final 
     *  result, and a carry which will be the input of the next row of partial
     *  products or the MSB of the result if it's the last row. 
     */
    genvar i;
    generate
        for (i = 0; i < PRODUCT_PER_STAGE; ++i) begin 
            if (i == 0) begin
                long_multiplier_product_row #(DATA_WIDTH) multiplier_row (
                    .and_product_i     ( and_product[0][DATA_WIDTH - 1:0]     ),
                    .partial_product_i ( last_partial_prod_i                  ),
                    .prev_carry_i      ( carry_i                              ),
                    .result_o          ( partial_product[0][DATA_WIDTH - 1:1] ),
                    .product_bit_o     ( final_result_bits_o[0]               ),
                    .carry_o           ( carry_next[0]                        ) 
                );
            end else begin
                long_multiplier_product_row #(DATA_WIDTH) multiplier_row (
                    .and_product_i     ( and_product[i]                           ),
                    .partial_product_i ( partial_product[i - 1][DATA_WIDTH - 1:1] ),
                    .prev_carry_i      ( carry_next[i - 1]                        ),
                    .result_o          ( partial_product[i][DATA_WIDTH - 1:1]     ),
                    .product_bit_o     ( final_result_bits_o[i]                   ),
                    .carry_o           ( carry_next[i]                            ) 
                );      
            end
        end
    endgenerate


    assign carry_o = carry_next[PRODUCT_PER_STAGE - 1];

    assign partial_product_o = partial_product[PRODUCT_PER_STAGE - 1][DATA_WIDTH - 1:1];


endmodule : pipelined_long_multiplier_stage