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
// FILE NAME : population_count_combinational.sv
// DEPARTMENT : 
// AUTHOR : Gabriele Tripi
// AUTHOR'S EMAIL : tripi.gabriele2002@gmail.com
// ------------------------------------------------------------------------------------
// RELEASE HISTORY
// VERSION : 1.0 
// DESCRIPTION : Count the number of 1 in a N bit word asyncronously.
//               Define ASYNC in a file included in the top module to enable 
//               asyncronous reset.
// ------------------------------------------------------------------------------------
// PARAMETERS
// NAME              : RANGE : ILLEGAL VALUES 
//-------------------------------------------------------------------------------------
// DATA_WIDTH        :   /   : Not a power of 2 
// ------------------------------------------------------------------------------------

`ifndef POPULATION_COUNT_COMBINATIONAL_SV
    `define POPULATION_COUNT_COMBINATIONAL_SV

module population_count_combinational #(

    /* Input number of bits */
    parameter DATA_WIDTH = 32,

    /* Number of nibbles in the operand */
    parameter NIBBLES_NUMBER = DATA_WIDTH / 4
) (
    input  logic [NIBBLES_NUMBER - 1:0][3:0] operand_i, 
    output logic [$clog2(DATA_WIDTH):0]      count_o
);

    /* Count bits in a single byte */
    logic [NIBBLES_NUMBER - 1:0][2:0] count_nibble;

        always_comb begin : byte_counter_network
            count_nibble = '0;
             
            for (int i = 0; i < NIBBLES_NUMBER; ++i) begin 
                case (operand_i[i]) 
                    4'b0000:          count_nibble[i] = 3'd0;

                    4'b0001, 4'b0010, 
                    4'b0100, 4'b1000: count_nibble[i] = 3'd1;

                    4'b0011, 4'b0101,
                    4'b1001, 4'b0110,
                    4'b1010, 4'b1100: count_nibble[i] = 3'd2;

                    4'b0111, 4'b1110,
                    4'b1011, 4'b1101: count_nibble[i] = 3'd3;

                    4'b1111:          count_nibble[i] = 3'd4;
                endcase 
            end  
        end : byte_counter_network

        always_comb begin : adder_network
            count_o = count_nibble[0]; 
            
            for (int i = 1; i < NIBBLES_NUMBER; ++i) begin 
                count_o += count_nibble[i]; 
            end 
        end : adder_network

endmodule : population_count_combinational

`endif 