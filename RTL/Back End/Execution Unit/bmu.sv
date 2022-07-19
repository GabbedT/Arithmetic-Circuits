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
// FILE NAME : bmu.sv
// DEPARTMENT : 
// AUTHOR : Gabriele Tripi
// AUTHOR'S EMAIL : tripi.gabriele2002@gmail.com
// ------------------------------------------------------------------------------------
// RELEASE HISTORY
// VERSION : 1.0 
// DESCRIPTION : Bit Manipulation Unit of the CPU, the module support the execution of
//               a subset of RISCV 'B' extension
// ------------------------------------------------------------------------------------


`ifndef BMU_INCLUDE_SV 
    `define BMU_INCLUDE_SV

`include "../../Include/configuration_pkg.sv"
`include "../../Include/rv32_instructions_pkg.sv"

`include "Arithmetic Circuits/Integer/Miscellaneous/CLZ/count_leading_zeros.sv"
`include "Arithmetic Circuits/Integer/Miscellaneous/CPOP/population_count.sv"

module bmu (
    input  logic              clk_i,
    input  logic              clk_en_i,
    input  logic              rst_n_i,
    input  logic [XLEN - 1:0] operand_A_i,
    input  logic [XLEN - 1:0] operand_B_i,
    input  bmu_operation_t    operation_i,
    input  logic              valid_i,
    input  logic              cpop_valid_i,
    
    output logic [XLEN - 1:0] result_o,
    output logic              valid_o,
    output logic              cpop_idle_o
);


//--------------------------//
//  SHIFT & ADD OPERATIONS  //
//--------------------------//

    /*
     *  SH1ADD, SH2ADD, SH3ADD
     */


    logic [XLEN - 1:0] shift_and_add_result;
    logic [1:0]        shift_amount;

    assign shift_and_add_result = operand_B_i + (operand_A_i << shift_amount);


        always_comb begin : shift_amount_assignment
            case (operation_i)
                SH1ADD:  shift_amount = 2'd1;

                SH2ADD:  shift_amount = 2'd2;

                SH3ADD:  shift_amount = 2'd3;

                default: shift_amount = 2'd0;
            endcase
        end : shift_amount_assignment


//--------------------//
//  LOGIC OPERATIONS  //
//--------------------//

    /*
     *  ANDN, ORN, XNOR
     */


    logic [XLEN - 1:0] andn_result, orn_result, xnor_result;

    assign andn_result = operand_A_i & (~operand_B_i);
    assign orn_result = operand_A_i | (~operand_B_i);
    assign xnor_result = ~(operand_A_i ^ operand_B_i);


//------------------------//
//  BIT COUNT OPERATIONS  //
//------------------------//

    /*
     *  CLZ, CTZ, CPOP
     */


    /* CLZ logic */
    logic [XLEN - 1:0]         clz_operand; 
    logic [$clog2(XLEN) - 1:0] clz_result; 
    logic                      clz_all_zero;

    assign clz_operand = operand_A_i;

    count_leading_zero #(32) clz32 (
        .operand_i     ( clz_operand  ),
        .lz_count_o    ( clz_result   ),
        .is_all_zero_o ( clz_all_zero )
    );

    logic [XLEN - 1:0] clz_final;
    
    assign clz_final[$clog2(XLEN):0] = {clz_all_zero, (clz_all_zero == 1'b1) ? 4'b0 : clz_result};


    /* CTZ logic */
    logic [XLEN - 1:0]         ctz_operand; 
    logic [$clog2(XLEN) - 1:0] ctz_result; 
    logic                      ctz_all_zero;

        /* Count trailing zeroes (CTZ) is a CLZ with the inverted bits */
        always_comb begin : ctz_assignment_logic
            for (int i = 0; i < XLEN; ++i) begin
                ctz_operand[(XLEN - 1) - i] = operand_A_i[i];
            end
        end : ctz_assignment_logic

    count_leading_zero #(32) ctz32 (
        .operand_i     ( ctz_operand  ),
        .lz_count_o    ( ctz_result   ),
        .is_all_zero_o ( ctz_all_zero )
    );

    logic [XLEN - 1:0] ctz_final;
    
    assign ctz_final[$clog2(XLEN):0] = {ctz_all_zero, (ctz_all_zero == 1'b1) ? 4'b0 : ctz_result};


    /* CPOP logic */
    logic [$clog2(XLEN):0] cpop_result;
    
    logic cpop_valid;

    population_count #(XLEN) cpop (
        .clk_i        ( clk_i         ),
        .clk_en_i     ( clk_en_i      ),
        .rst_n_i      ( rst_n_i       ),
        .operand_i    ( operand_A_i   ),
        .data_valid_i ( cpop_valid_i  ),
        .data_valid_o ( cpop_valid    ),
        .idle_o       ( cpop_idle_o   ),
        .pop_count_o  ( cpop_result   )
    );


//------------------------//
//  COMPARISON OPERATIONS //
//------------------------//

    /*
     *  MAX, MAXU, MIN, MINU
     */


    /* MAX operation */
    logic [XLEN - 1:0] max_result, maxu_result;

    assign max_result = ($signed(operand_A_i) < $signed(operand_B_i)) ? operand_B_i : operand_A_i;

    assign maxu_result = ($unsigned(operand_A_i) < $unsigned(operand_B_i)) ? operand_B_i : operand_A_i;


    /* MIN operation */
    logic [XLEN - 1:0] min_result, minu_result;

    assign min_result = ($signed(operand_A_i) < $signed(operand_B_i)) ? operand_A_i : operand_B_i;

    assign minu_result = ($unsigned(operand_A_i) < $unsigned(operand_B_i)) ? operand_A_i : operand_B_i;


//--------------------------//
//  SIGN EXTEND OPERATIONS  //
//--------------------------//

    /*
     *  SEXT.B, SEXT.H, ZEXT.H
     */


    logic [XLEN - 1:0] sextb_result, sexth_result, zexth_result;

    assign sextb_result = $signed(operand_A_i[7:0]);

    assign sexth_result = $signed(operand_A_i[15:0]);

    assign zexth_result = $unsigned(operand_A_i[15:0]);


//---------------------//
//  ROTATE OPERATIONS  //
//---------------------//

    /*
     *  ROL, ROR, RORI
     */


    logic [XLEN - 1:0] rol_result, ror_result;

    assign rol_result = (operand_A_i << operand_B_i[4:0]) | (operand_A_i >> (XLEN - operand_B_i[4:0]));

    assign ror_result = (operand_A_i >> operand_B_i[4:0]) | (operand_A_i << (XLEN - operand_B_i[4:0]));


//-------------------//
//  BYTE OPERATIONS  //
//-------------------//

    /*
     *  ORC.B, REV8
     */


    logic [(XLEN / 8) - 1:0][7:0] orcb_result, orcb_operand;

        always_comb begin : or_combine_logic
            orcb_operand = operand_A_i;

            for (int i = 0; i < (XLEN / 8); ++i) begin
                orcb_result[i] = $signed(|orcb_operand[i]);
            end
        end : or_combine_logic


    logic [(XLEN / 8) - 1:0][7:0] rev8_result, rev8_operand;

        always_comb begin : reverse_byte_logic
            rev8_operand = operand_A_i;

            for (int i = 0; i < (XLEN / 8); ++i) begin
                rev8_result[((XLEN / 8) - 1) - i] = rev8_operand[i];
            end
        end : reverse_byte_logic


//------------------//
//  BIT OPERATIONS  //
//------------------//

    /*
     *  BCLR, BCLRI, BEXT, BEXTI, 
     *  BINV, BINVI, BSET, BSETI
     */


    logic [$clog2(XLEN) - 1:0] rot_amount;

    assign rot_amount = operand_B_i[$clog2(XLEN) - 1:0];

    
    /* Bit clear */
    logic [XLEN - 1:0] bclr_result;

    assign bclr_result = operand_A_i & ~(1 << rot_amount);


    /* Bit extract */
    logic bext_result;

    assign bext_result = operand_A_i >> rot_amount;


    /* Bit invert */
    logic [XLEN - 1:0] binv_result;

    assign binv_result = operand_A_i ^ (1 << rot_amount);


    /* Bit set */
    logic [XLEN - 1:0] bset_result;

    assign bset_result = operand_A_i | (1 << rot_amount);


//----------------//
//  RESULT LOGIC  //
//----------------//

    /* For single cycle operations */
    assign valid_o = valid_i | cpop_valid;

        always_comb begin : output_logic 
            case (operation_i)
                SH1ADD, SH2ADD, SH3ADD: result_o = shift_and_add_result;

                ANDN: result_o = andn_result;

                ORN: result_o = orn_result;

                XNOR: result_o = xnor_result;

                CLZ: result_o = clz_final;

                CTZ: result_o = ctz_final;

                MAX: result_o = max_result;

                MAXU: result_o = maxu_result;

                MIN: result_o = min_result;

                MINU: result_o = minu_result;

                SEXTB: result_o = sextb_result;

                SEXTH: result_o = sexth_result;

                ZEXTH: result_o = zexth_result;

                ROL: result_o = rol_result;

                ROR, RORI: result_o = ror_result;

                ORCB: result_o = orcb_result;

                REV8: result_o = rev8_result;

                BCLR, BCLRI: result_o = bclr_result;

                BEXT, BEXTI: result_o = bext_result;

                BINV, BINVI: result_o = binv_result;

                BSET, BSETI: result_o = bset_result;

                default: result_o = operand_A_i;
            endcase
        end : output_logic

endmodule : bmu

`endif