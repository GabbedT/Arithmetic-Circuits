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
// FILE NAME : alu.sv
// DEPARTMENT : 
// AUTHOR : Gabriele Tripi
// AUTHOR'S EMAIL : tripi.gabriele2002@gmail.com
// ------------------------------------------------------------------------------------
// RELEASE HISTORY
// VERSION : 1.0 
// DESCRIPTION : Arithmetic Logic Unit of the CPU, the module is fully combinational 
//               and every instruction executed is single cycle.
// ------------------------------------------------------------------------------------


`ifndef ALU_INCLUDE_SV 
    `define ALU_INCLUDE_SV

`include "../../Include/configuration_pkg.sv"
`include "../../Include/rv32_instructions_pkg.sv"

module alu (
    input  logic [XLEN - 1:0] operand_A_i,
    input  logic [XLEN - 1:0] operand_B_i,
    input  alu_operation_t    operation_i,
    input  logic              valid_i,
    
    output logic [XLEN - 1:0] result_o,
    output logic              enable_pc_write_o,
    output logic              valid_o
);


//--------------//
//  MAIN ADDER  //
//--------------//

    /* 
     *  ADDI, ADD, SUB, LUI, AUIPC, JAL, JALR
     */

    logic [XLEN - 1:0] adder_result, operand_B;

    assign operand_B = (operation_i == SUB) ? (~operand_B_i + 1'b1) : operand_B_i;

    assign adder_result = operand_A_i + operand_B;


//-------------------//
//  NEXT PC OUTCOME  //
//-------------------//

    /*
     *  JAL, JALR, BEQ, BNE, BLT, BLTU, BGE, BGEU
     */

    /* Signed */
    logic is_greater_or_equal_s, is_less_than_s;

    assign is_greater_or_equal_s = $signed(operand_A_i) >= $signed(operand_B_i);
    assign is_less_than_s = $signed(operand_A_i) < $signed(operand_B_i);


    /* Unsigned */
    logic is_greater_or_equal_u, is_less_than_u;

    assign is_greater_or_equal_u = $unsigned(operand_A_i) >= $unsigned(operand_B_i);
    assign is_less_than_u = $unsigned(operand_A_i) < $unsigned(operand_B_i);


    logic is_equal;

    assign is_equal = (operand_A_i == operand_B_i);


        always_comb begin : comparison_outcome
            case (operation_i)
                JAL:  enable_pc_write_o = 1'b1;

                JALR: enable_pc_write_o = 1'b1;

                BEQ:  enable_pc_write_o = is_equal;

                BNE:  enable_pc_write_o = !is_equal;

                BLT:  enable_pc_write_o = is_less_than_s;

                BLTU: enable_pc_write_o = is_less_than_u;

                BGE:  enable_pc_write_o = is_greater_or_equal_s;

                BGEU: enable_pc_write_o = is_greater_or_equal_u;

                default: enable_pc_write_o = 1'b0;
            endcase
        end : comparison_outcome


//-----------//
//  SHIFTER  //
//-----------//

    /*
     *  SLL, SLLI, SRL, SRLI, SRA, SRAI
     */

    logic [XLEN - 1:0] logical_sh_left_result, logical_sh_right_result, arithmetic_sh_right_result;
    logic [XLEN - 1:0] shifter_input1; 
    logic [4:0]        shifter_input2;

    /* First operator is always a register */
    assign shifter_input1 = operand_A_i;

    /* Shift amount is held in the lower 5 bit of the register / immediate */
    assign shifter_input2 = operand_B_i[4:0];

    assign logical_sh_left_result = shifter_input1 << shifter_input2;
    assign logical_sh_right_result = shifter_input1 >> shifter_input2;
    assign arithmetic_sh_right_result = $signed(shifter_input1) >>> $signed(shifter_input2);


//-------------------//
//  LOGIC OPERATION  //
//-------------------//

    logic [XLEN - 1:0] and_result, or_result, xor_result;

    assign and_result = operand_A_i & operand_B_i;
    assign or_result = operand_A_i | operand_B_i;
    assign xor_result = operand_A_i ^ operand_B_i;


//----------------//
//  RESULT LOGIC  //
//----------------//

    /*
     *  AND, OR, XOR
     */

    assign valid_o = valid_i;


        always_comb begin : output_assignment
            case (operation_i)
                ADDI, ADD, SUB: result_o = adder_result;

                SLTI, SLT: result_o = is_less_than_s;

                SLTIU, SLTU: result_o = is_less_than_u;

                ANDI, AND: result_o = and_result;

                ORI, OR: result_o = or_result;

                XORI, XOR: result_o = xor_result;

                LUI, AUIPC: result_o = adder_result;

                SLL, SLLI: result_o = logical_sh_left_result;

                SRL, SRLI: result_o = logical_sh_right_result;

                SRAI, SRA: result_o = arithmetic_sh_right_result;

                JAL, JALR: result_o = adder_result;

                /* Conditional jump operation */
                default: result_o = 'b0;
            endcase
        end : output_assignment

endmodule

`endif 