`ifndef RV32_INSTRUCTION_INCLUDE_SV
    `define RV32_INSTRUCTION_INCLUDE_SV

package rv32_instructions_pkg;

//------------------//
//  ALU OPERATIONS  //
//------------------//

    typedef enum logic [4:0] {
        /* Jump instructions */
        JAL, JALR, BEQ, BNE, BGE, 
        BLT, BLTU, BGEU,

        /* Arithmetic and logic instructions */
        ADD, SUB, ADDI,
        SLL, SLLI, SRL, SRLI, SRA, SRAI,
        AND, ANDI, OR, ORI, XOR, XORI,
        SLT, SLTI, SLTU, SLTIU,

        /* Load instructions */
        LUI, AUIPC
    } alu_operation_t;

    
//------------------//
//  BMU OPERATIONS  //
//------------------//

    typedef enum logic [4:0] {
        /* ZBA instructions */
        SH1ADD, SH2ADD, SH3ADD, 

        /* ZBB instructions */
        ANDN, ORN, XNOR, CLZ, CTZ, CPOP,
        MAX, MAXU, MIN, MINU, SEXTB, SEXTH, 
        ZEXTH, ROL, ROR, RORI, ORCB, REV8,

        /* ZBS instructions */
        BCLR, BCLRI, BEXT, BEXTI, BINV, 
        BINVI, BSET, BSETI
    } bmu_operation_t;


//----------------------------//
//  MULTIPLY UNIT OPERATIONS  //
//----------------------------//

    typedef enum logic [1:0] {  
        /* Multiplication instructions */
        MUL, MULH, MULHSU, MULHU 
    } mul_operation_t;


//--------------------------//
//  DIVIDE UNIT OPERATIONS  //
//--------------------------//

    typedef enum logic [1:0] {  
        /* Division instructions */
        DIV, DIVU, REM, REMU
    } div_operation_t;


//------------------//
//  FPU OPERATIONS  //
//------------------//

    typedef enum logic [4:0] {
        /* Arithmetic instructions */
        FMADD, FMSUB, FNMSUB, FNMADD,
        FADD, FSUB, FMUL, FDIV, FSQRT,

        /* Miscellaneous instructions */
        FSGNJ, FSGNJN, FSGNJX, FCLASS,
        FCVTSW, FCVTSWU, FCVTWS, FCVTWUS,
        FMVWX, FMVXW,

        /* Comparison instructions */
        FMIN, FMAX, FEQ, FLT, FLE 
    } fpu_operation_t;


//--------------------------//
//  MEMORY UNIT OPERATIONS  //
//--------------------------//

    typedef enum logic [3:0] {
        /* Load instructions */
        LB, LH, LW, LBU, LHU, FLW,

        /* Store instructions */
        SB, SH, SW, FSW
    } mem_operation_t;


//-----------------------------//
//  EXECUTION UNIT OPERATIONS  //
//-----------------------------//

    typedef struct packed {
        alu_operation_t  ALU;
        bmu_operation_t  BMU;
        mul_operation_t  MUL;
        div_operation_t  DIV;
        fpu_operation_t  FPU;
        mem_operation_t  MEM;
    } exu_operation_t;


endpackage : rv32_instructions_pkg

import rv32_instructions_pkg::*;

`endif 