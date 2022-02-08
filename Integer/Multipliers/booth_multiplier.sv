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
// FILE NAME : booth_multiplier.sv
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
//               when the inputs are valid. Once the signal "data_valid_i" is high
//               at the same time new inputs can be elaborated without compromising
//               the validity of the preceeding output.
// ------------------------------------------------------------------------------------
// REFERENCE:
//
// * https://en.wikipedia.org/wiki/Booth%27s_multiplication_algorithm
// * https://ieeexplore.ieee.org/document/276194
// ------------------------------------------------------------------------------------
// KEYWORDS : BOOTH_RULES, RADIX
// ------------------------------------------------------------------------------------
// PARAMETERS
// PARAM NAME :    RANGE    : DESCRIPTION                                : DEFAULT 
// DATA_WIDTH :       /     : I/O number of bits                         : 32
// RADIX      :  [16|8|4|2] : log2(RADIX) is the number of bits recoded  : 2
// ------------------------------------------------------------------------------------

module booth_multiplier #(

  // Number of bits in a word
  parameter DATA_WIDTH = 32,

  // The logarithm of this parameter gives the number of bits recoded
  parameter RADIX = 16
)
(
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

  // Current and next 
  localparam CRT = 0;
  localparam NXT = 1;

  localparam COUNTER_BITS = $clog2(DATA_WIDTH / $clog2(RADIX));

  // Number of bits recoded by booth algorithm
  localparam RECODED_BITS = $clog2(RADIX);
  localparam SHIFT_AMOUNT = RECODED_BITS;

  // Since the B operand is shifted at maximum of SHIFT_AMOUNT - 1 
  // the registers P and B should be that amount of bits wider to 
  // accomodate the shifted bits.
  localparam TOTAL_BITS = DATA_WIDTH + (SHIFT_AMOUNT - 1);

//-----------//
// FSM LOGIC //
//-----------//
  
  // Possible states of FSM
  typedef enum logic {IDLE, MULTIPLY} fsm_state_e;

  // Current and next state of fsm
  fsm_state_e [NXT:CRT] state;
  
  logic [NXT:CRT][COUNTER_BITS - 1:0] counter;

  // Delay the reset signals by 1 cycle because the FSM should
  // stay 2 cycles in the IDLE stage when resetted
  logic rst_n_dly;

      always_ff @(posedge clk_i)
        begin
          rst_n_dly <= rst_n_i;
        end

      always_ff @(posedge clk_i)
        begin : state_register
          if (!rst_n_i) begin 
            state[CRT] <= IDLE;
          end if (clk_en_i) begin 
            state[CRT] <= state[NXT];
          end           
        end : state_register

      always_comb 
        begin : next_state_logic
          case (state[CRT])
            IDLE:     state[NXT] = (!rst_n_dly) ? IDLE : MULTIPLY;
            
            MULTIPLY: state[NXT] = (counter[CRT] == (2**COUNTER_BITS - 1)) ? IDLE : MULTIPLY;

            default:  state[NXT] = IDLE;
          endcase
        end : next_state_logic

//------------//
//  DATAPATH  //
//------------//

  typedef struct packed {
      logic signed [TOTAL_BITS - 1:0] _P; //Partial product
      logic signed [DATA_WIDTH - 1:0] _A; //Multiplier
      logic                           _L; //Last bit shifted
  } reg_pair_s;

  // Flip-Flop nets 
  reg_pair_s [NXT:CRT] reg_pair_ff;

  logic [TOTAL_BITS - 1:0] partial_product;

  //Multiplicand register nets
  logic [NXT:CRT][TOTAL_BITS - 1:0] reg_B_ff;
  
  // Shifted partial product
  reg_pair_s partial_product_sh;
  
      always_comb 
        begin : next_output_logic
          case (state[CRT])
            IDLE: begin 
                    // Initialize values
                    reg_pair_ff[NXT]._P = 'b0;
                    reg_pair_ff[NXT]._A = operand_A_i;
                    reg_pair_ff[NXT]._L = 1'b0;
                    
                    // Sign extend 
                    reg_B_ff[NXT] = $signed(operand_B_i);
                    counter[NXT] = 'b0;
                  end

            MULTIPLY: begin 
                        // Update the partial product every cycle
                        reg_pair_ff[NXT] = partial_product_sh;
                        // Keep the same value
                        reg_B_ff[NXT] = reg_B_ff[CRT];
                        // Increment the counter
                        counter[NXT] = counter[CRT] + 1;
                      end

            default:  begin 
                        reg_pair_ff[NXT]._P = 'bX;
                        reg_pair_ff[NXT]._A = 'bX;
                        reg_pair_ff[NXT]._L = 1'bX;
                        reg_B_ff[NXT] = 'bX;
                        counter[NXT] = 'bX;
                      end
          endcase
        end : next_output_logic

      always_ff @(posedge clk_i)
        begin : output_register
          if (!rst_n_i) begin 
            reg_pair_ff[CRT] <= 'b0;
            reg_B_ff[CRT] <= 'b0;
          end else if (clk_en_i) begin
            reg_pair_ff[CRT] <= reg_pair_ff[NXT];
            reg_B_ff[CRT] <= reg_B_ff[NXT];              
          end
        end : output_register
  
  // Select the correct signal to add to P register    
  logic [TOTAL_BITS - 1:0] reg_B_sel;

  generate

    if (RADIX == 2) begin 
      always_comb 
        begin
          case ({reg_pair_ff[CRT]._A[RECODED_BITS - 1:0], reg_pair_ff[CRT]._L})    
            2'b00,
            2'b11:    reg_B_sel = 'b0;

            2'b01:    reg_B_sel = reg_B_ff[CRT]; 

            2'b10:    reg_B_sel = -reg_B_ff[CRT];  
          endcase

          partial_product = reg_pair_ff[CRT]._P + reg_B_sel; 
          partial_product_sh = $signed({partial_product, reg_pair_ff[CRT]._A, reg_pair_ff[CRT]._L}) >>> SHIFT_AMOUNT;
        end
    end else if (RADIX == 4) begin 
      always_comb 
        begin  
          case ({reg_pair_ff[CRT]._A[RECODED_BITS - 1:0], reg_pair_ff[CRT]._L})    
            3'b000,
            3'b111:   reg_B_sel = 'b0;

            3'b001,
            3'b010:   reg_B_sel = reg_B_ff[CRT];

            3'b011:   reg_B_sel = reg_B_ff[CRT] << 1;   

            3'b100:   reg_B_sel = -(reg_B_ff[CRT] << 1);   

            3'b101,
            3'b110:   reg_B_sel = -reg_B_ff[CRT];
          endcase

          partial_product = reg_pair_ff[CRT]._P + reg_B_sel;
          partial_product_sh = $signed({partial_product, reg_pair_ff[CRT]._A, reg_pair_ff[CRT]._L}) >>> SHIFT_AMOUNT;
        end
    end else if (RADIX == 8) begin 
      always_comb 
        begin 
          case ({reg_pair_ff[CRT]._A[RECODED_BITS - 1:0], reg_pair_ff[CRT]._L})    
            4'b0000,
            4'b1111:    reg_B_sel = 'b0;

            4'b0001,
            4'b0010:    reg_B_sel = reg_B_ff[CRT];

            4'b0011,
            4'b0100:    reg_B_sel = (reg_B_ff[CRT] << 1);   

            4'b0101,
            4'b0110:    reg_B_sel = ((reg_B_ff[CRT] << 1) + reg_B_ff[CRT]);

            4'b0111:    reg_B_sel = (reg_B_ff[CRT] << 2);

            4'b1000:    reg_B_sel = -(reg_B_ff[CRT] << 2);

            4'b1001,
            4'b1010:    reg_B_sel = -((reg_B_ff[CRT] << 1) + reg_B_ff[CRT]);

            4'b1011,
            4'b1100:    reg_B_sel = -(reg_B_ff[CRT] << 1);   
                      
            4'b1101,
            4'b1110:    reg_B_sel = -reg_B_ff[CRT];
          endcase

          partial_product = reg_pair_ff[CRT]._P + reg_B_sel;
          partial_product_sh = $signed({partial_product, reg_pair_ff[CRT]._A, reg_pair_ff[CRT]._L}) >>> SHIFT_AMOUNT;
        end
    end else if (RADIX == 16) begin 
      always_comb 
        begin
          case ({reg_pair_ff[CRT]._A[RECODED_BITS - 1:0], reg_pair_ff[CRT]._L})    
            5'b00000,
            5'b11111:    reg_B_sel = 'b0;   

            5'b00001,
            5'b00010:    reg_B_sel = reg_B_ff[CRT];   
                      
            5'b00011,
            5'b00100:    reg_B_sel = (reg_B_ff[CRT] << 1);   

            5'b00101,
            5'b00110:    reg_B_sel = ((reg_B_ff[CRT] << 1) + reg_B_ff[CRT]);    

            5'b00111,
            5'b01000:    reg_B_sel = (reg_B_ff[CRT] << 2);   

            5'b01001,
            5'b01010:    reg_B_sel = ((reg_B_ff[CRT] << 2) + reg_B_ff[CRT]);    

            5'b01011,
            5'b01100:    reg_B_sel = ((reg_B_ff[CRT] << 2) + (reg_B_ff[CRT] << 1));   

            5'b01101,
            5'b01110:    reg_B_sel = ((reg_B_ff[CRT] << 2) + (reg_B_ff[CRT] << 1) + reg_B_ff[CRT]);   

            5'b01111:    reg_B_sel = (reg_B_ff[CRT] << 3);    

            5'b10000:    reg_B_sel = -(reg_B_ff[CRT] << 3);    
                      
            5'b10001,
            5'b10010:    reg_B_sel = -((reg_B_ff[CRT] << 2) + (reg_B_ff[CRT] << 1) + reg_B_ff[CRT]);    

            5'b10011,
            5'b10100:    reg_B_sel = -((reg_B_ff[CRT] << 2) + (reg_B_ff[CRT] << 1));    

            5'b10101,
            5'b10110:    reg_B_sel = -((reg_B_ff[CRT] << 2) + reg_B_ff[CRT]);   

            5'b10111,
            5'b11000:    reg_B_sel = -(reg_B_ff[CRT] << 2);    

            5'b11001,
            5'b11010:    reg_B_sel = -((reg_B_ff[CRT] << 1) + reg_B_ff[CRT]);    

            5'b11011,
            5'b11100:    reg_B_sel = -(reg_B_ff[CRT] << 1);    

            5'b11101,
            5'b11110:    reg_B_sel = -reg_B_ff[CRT];   
          endcase

          partial_product = reg_pair_ff[CRT]._P + reg_B_sel;
          partial_product_sh = $signed({partial_product, reg_pair_ff[CRT]._A, reg_pair_ff[CRT]._L}) >>> SHIFT_AMOUNT;
        end
    end

  endgenerate 

      always_ff @(posedge clk_i)
        begin : counter_logic
          if (!rst_n_i) begin
            counter[CRT] <= 'b0;
          end else if (clk_en_i) begin 
            counter[CRT] <= counter[NXT];
          end           
        end : counter_logic
  
  logic [CRT:NXT] valid_entry;
  
  // If not in state IDLE recycle the current value
  assign valid_entry[NXT] = (state[CRT] == IDLE) ? valid_entry_i : valid_entry[CRT];

        always_ff @(posedge clk_i) 
          begin : valid_register
            if (!rst_n_i) begin 
              valid_entry[CRT] <= 'b0;
            end else if (clk_en_i) begin 
              valid_entry[CRT] <= valid_entry[NXT];
            end
          end : valid_register

  assign result_o = {reg_pair_ff[CRT]._P[DATA_WIDTH - 1:0], reg_pair_ff[CRT]._A};
  
  assign data_valid_o = (state[CRT] == IDLE) & valid_entry[CRT];

  assign busy_o = state[CRT] == MULTIPLY;

endmodule
