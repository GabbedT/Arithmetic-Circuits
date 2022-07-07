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
// --------------------------------------------------------------------------------
// ------------------------------------------------------------------------------------
// FILE NAME : sequential_booth_multiplier.sv
// DEPARTMENT : 
// AUTHOR : Gabriele Tripi
// AUTHOR'S EMAIL :
// ------------------------------------------------------------------------------------
// RELEASE HISTORY
// VERSION : 1.0 
// DESCRIPTION : This module perform a SIGNED multiplication using booth algorithm
//               sequentially. The LATENCY of this multiplier is calculated:
//               (DATA_WIDTH / log2(RADIX)) + 1. Disable the signal "clk_en_i"
//               to stop the execution. The signal "valid_entry_i" must be asserted
//               when the inputs are valid for 1 clock cycle. Once the signal is high
//               the new inputs can be elaborated, "busy_o" is asserted during this 
//               time. After a fixed amount of cycles (depends on the two parameters), 
//               output become valid as well as the signal "data_valid_o" for 1 clock 
//               cycle. 
// ------------------------------------------------------------------------------------
// REFERENCE: P. E. Madrid, B. Millar and E. E. Swartzlander, "Modified Booth algorithm 
//            for high radix multiplication," Proceedings 1992 IEEE International 
//            Conference on Computer Design: VLSI in Computers & Processors, 1992, 
//            pp. 118-121, doi: 10.1109/ICCD.1992.276194.
//
//            https://ieeexplore.ieee.org/document/276194
// ------------------------------------------------------------------------------------
// KEYWORDS : BOOTH_RULES, RADIX
// ------------------------------------------------------------------------------------
// PARAMETERS
// PARAM NAME :    RANGE    : DESCRIPTION                                : DEFAULT 
// DATA_WIDTH :       /     : I/O number of bits                         : 32
// RADIX      :  [16|8|4|2] : log2(RADIX) is the number of bits recoded  : 2
// ------------------------------------------------------------------------------------

module sequential_booth_multiplier #(

    /* Number of bits in a word */
    parameter DATA_WIDTH = 32,

    /* The logarithm of this parameter gives the number of bits recoded */
    parameter RADIX = 16
) (
    input  logic [DATA_WIDTH - 1:0]       operand_A_i,
    input  logic [DATA_WIDTH - 1:0]       operand_B_i,
    input  logic                          clk_i,
    input  logic                          clk_en_i,
    input  logic                          rst_n_i,
    input  logic                          valid_entry_i,

    output logic [(2 * DATA_WIDTH) - 1:0] result_o,
    output logic                          data_valid_o,
    output logic                          busy_o
);

//------------//
// PARAMETERS //
//------------//

    /* Current and next */
    localparam CRT = 0;
    localparam NXT = 1;

    localparam COUNTER_BITS = $clog2(DATA_WIDTH / $clog2(RADIX));

    /* Number of bits recoded by booth algorithm */
    localparam RECODED_BITS = $clog2(RADIX);
    localparam SHIFT_AMOUNT = RECODED_BITS;

    /* Since the B operand is shifted at maximum of SHIFT_AMOUNT - 1 
     * the registers P and B should be that amount of bits wider to 
     * accomodate the shifted bits. */
    localparam TOTAL_BITS = DATA_WIDTH + (SHIFT_AMOUNT - 1);


//-----------//
// FSM LOGIC //
//-----------//
  
    /* Possible states of FSM */
    typedef enum logic {IDLE, MULTIPLY} fsm_state_e;

    /* Current and next state of fsm */
    fsm_state_e state_CRT, state_NXT;
    
    logic [COUNTER_BITS - 1:0] counter_CRT, counter_NXT;
 
        always_ff @(posedge clk_i or negedge rst_n_i) begin : state_register
            if (!rst_n_i) begin 
                state_CRT <= IDLE;
            end else if (clk_en_i) begin 
                state_CRT <= state_NXT;
            end           
        end : state_register

        always_comb begin : next_state_logic
            case (state_CRT)
                IDLE:     state_NXT = (valid_entry_i) ? MULTIPLY : IDLE;
                
                MULTIPLY: state_NXT = (counter_CRT == (2**COUNTER_BITS - 1)) ? IDLE : MULTIPLY;

                default:  state_NXT = IDLE;
            endcase
        end : next_state_logic


//------------//
//  DATAPATH  //
//------------//

    typedef struct packed {
        /* Partial product */
        logic signed [TOTAL_BITS - 1:0] _P; 

        /* Multiplier */
        logic signed [DATA_WIDTH - 1:0] _A; 

        /* Last bit shifted */
        logic                           _L; 
    } reg_pair_s;

    /* Flip-Flop nets */
    reg_pair_s reg_pair_ff_CRT, reg_pair_ff_NXT;

    logic [TOTAL_BITS - 1:0] partial_product;

    /* Multiplicand register nets */
    logic [TOTAL_BITS - 1:0] reg_B_ff_CRT, reg_B_ff_NXT;
    
    /* Shifted partial product */
    reg_pair_s partial_product_sh;
  

        always_comb begin : datapath_logic
            case (state_CRT)
                IDLE: begin 
                    /* Initialize values */
                    reg_pair_ff_NXT._P = 'b0;
                    reg_pair_ff_NXT._A = operand_A_i;
                    reg_pair_ff_NXT._L = 1'b0;
                    
                    /* Sign extend */
                    reg_B_ff_NXT = $signed(operand_B_i);
                    counter_NXT = 'b0;
                end

                MULTIPLY: begin 
                    /* Update the partial product every cycle */
                    reg_pair_ff_NXT = partial_product_sh;

                    /* Keep the same value */
                    reg_B_ff_NXT = reg_B_ff_CRT;

                    /* Increment the counter */
                    counter_NXT = counter_CRT + 1;
                end
          endcase
        end : datapath_logic

        always_ff @(posedge clk_i) begin : datapath_register
            if (clk_en_i) begin
                reg_pair_ff_CRT <= reg_pair_ff_NXT;
                reg_B_ff_CRT <= reg_B_ff_NXT;              
            end
        end : datapath_register
  
    /* Select the correct signal to add to P register */   
    logic [TOTAL_BITS - 1:0] reg_B_sel;

    generate

        if (RADIX == 2) begin 
            always_comb begin
                case ({reg_pair_ff_CRT._A[RECODED_BITS - 1:0], reg_pair_ff_CRT._L})    
                    2'b00,
                    2'b11:    reg_B_sel = 'b0;

                    2'b01:    reg_B_sel = reg_B_ff_CRT; 

                    2'b10:    reg_B_sel = -reg_B_ff_CRT;  
                endcase

                partial_product = reg_pair_ff_CRT._P + reg_B_sel; 
                partial_product_sh = $signed({partial_product, reg_pair_ff_CRT._A, reg_pair_ff_CRT._L}) >>> SHIFT_AMOUNT;
            end
        end else if (RADIX == 4) begin 
            always_comb begin  
                case ({reg_pair_ff_CRT._A[RECODED_BITS - 1:0], reg_pair_ff_CRT._L})    
                    3'b000,
                    3'b111:   reg_B_sel = 'b0;

                    3'b001,
                    3'b010:   reg_B_sel = reg_B_ff_CRT;

                    3'b011:   reg_B_sel = reg_B_ff_CRT << 1;   

                    3'b100:   reg_B_sel = -(reg_B_ff_CRT << 1);   

                    3'b101,
                    3'b110:   reg_B_sel = -reg_B_ff_CRT;
                endcase

                partial_product = reg_pair_ff_CRT._P + reg_B_sel;
                partial_product_sh = $signed({partial_product, reg_pair_ff_CRT._A, reg_pair_ff_CRT._L}) >>> SHIFT_AMOUNT;
            end
        end else if (RADIX == 8) begin 
            always_comb begin 
                case ({reg_pair_ff_CRT._A[RECODED_BITS - 1:0], reg_pair_ff_CRT._L})    
                    4'b0000,
                    4'b1111:    reg_B_sel = 'b0;

                    4'b0001,
                    4'b0010:    reg_B_sel = reg_B_ff_CRT;

                    4'b0011,
                    4'b0100:    reg_B_sel = (reg_B_ff_CRT << 1);   

                    4'b0101,
                    4'b0110:    reg_B_sel = ((reg_B_ff_CRT << 1) + reg_B_ff_CRT);

                    4'b0111:    reg_B_sel = (reg_B_ff_CRT << 2);

                    4'b1000:    reg_B_sel = -(reg_B_ff_CRT << 2);

                    4'b1001,
                    4'b1010:    reg_B_sel = -((reg_B_ff_CRT << 1) + reg_B_ff_CRT);

                    4'b1011,
                    4'b1100:    reg_B_sel = -(reg_B_ff_CRT << 1);   
                            
                    4'b1101,
                    4'b1110:    reg_B_sel = -reg_B_ff_CRT;
                endcase

                partial_product = reg_pair_ff_CRT._P + reg_B_sel;
                partial_product_sh = $signed({partial_product, reg_pair_ff_CRT._A, reg_pair_ff_CRT._L}) >>> SHIFT_AMOUNT;
            end
        end else if (RADIX == 16) begin 
            always_comb begin
                case ({reg_pair_ff_CRT._A[RECODED_BITS - 1:0], reg_pair_ff_CRT._L})    
                    5'b00000,
                    5'b11111:    reg_B_sel = 'b0;   

                    5'b00001,
                    5'b00010:    reg_B_sel = reg_B_ff_CRT;   
                            
                    5'b00011,
                    5'b00100:    reg_B_sel = (reg_B_ff_CRT << 1);   

                    5'b00101,
                    5'b00110:    reg_B_sel = ((reg_B_ff_CRT << 1) + reg_B_ff_CRT);    

                    5'b00111,
                    5'b01000:    reg_B_sel = (reg_B_ff_CRT << 2);   

                    5'b01001,
                    5'b01010:    reg_B_sel = ((reg_B_ff_CRT << 2) + reg_B_ff_CRT);    

                    5'b01011,
                    5'b01100:    reg_B_sel = ((reg_B_ff_CRT << 2) + (reg_B_ff_CRT << 1));   

                    5'b01101,
                    5'b01110:    reg_B_sel = ((reg_B_ff_CRT << 2) + (reg_B_ff_CRT << 1) + reg_B_ff_CRT);   

                    5'b01111:    reg_B_sel = (reg_B_ff_CRT << 3);    

                    5'b10000:    reg_B_sel = -(reg_B_ff_CRT << 3);    
                            
                    5'b10001,
                    5'b10010:    reg_B_sel = -((reg_B_ff_CRT << 2) + (reg_B_ff_CRT << 1) + reg_B_ff_CRT);    

                    5'b10011,
                    5'b10100:    reg_B_sel = -((reg_B_ff_CRT << 2) + (reg_B_ff_CRT << 1));    

                    5'b10101,
                    5'b10110:    reg_B_sel = -((reg_B_ff_CRT << 2) + reg_B_ff_CRT);   

                    5'b10111,
                    5'b11000:    reg_B_sel = -(reg_B_ff_CRT << 2);    

                    5'b11001,
                    5'b11010:    reg_B_sel = -((reg_B_ff_CRT << 1) + reg_B_ff_CRT);    

                    5'b11011,
                    5'b11100:    reg_B_sel = -(reg_B_ff_CRT << 1);    

                    5'b11101,
                    5'b11110:    reg_B_sel = -reg_B_ff_CRT;   
                endcase

                partial_product = reg_pair_ff_CRT._P + reg_B_sel;
                partial_product_sh = $signed({partial_product, reg_pair_ff_CRT._A, reg_pair_ff_CRT._L}) >>> SHIFT_AMOUNT;
            end
        end

    endgenerate 


        always_ff @(posedge clk_i or negedge rst_n_i) begin : counter_logic
            if (!rst_n_i) begin
                counter_CRT <= 'b0;
            end else if (clk_en_i) begin 
                counter_CRT <= counter_NXT;
            end           
        end : counter_logic
  

    logic valid_entry_CRT, valid_entry_NXT;
  
    /* If not in state IDLE recycle the current value */
    assign valid_entry_NXT = (state_CRT == IDLE) ? valid_entry_i : valid_entry_CRT;

        always_ff @(posedge clk_i) begin : valid_register
            if (!rst_n_i) begin 
                valid_entry_CRT <= 'b0;
            end else if (clk_en_i) begin 
                valid_entry_CRT <= valid_entry_NXT;
            end
        end : valid_register

    assign result_o = {reg_pair_ff_CRT._P[DATA_WIDTH - 1:0], reg_pair_ff_CRT._A};
    
    assign data_valid_o = (state_CRT == IDLE) & valid_entry_CRT;

    assign busy_o = (state_CRT == MULTIPLY);

endmodule : sequential_booth_multiplier
