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
// FILE NAME : non_restoring_square_root.sv
// DEPARTMENT : 
// AUTHOR : Gabriele Tripi
// AUTHOR'S EMAIL : tripi.gabriele2002@gmail.com
// ------------------------------------------------------------------------------------
// RELEASE HISTORY
// VERSION : 1.0 
// DESCRIPTION : This module perform an unsigned square root using the algorithm
//               proposed below iteratively in around O(n/2) time. The signal 
//               "valid_entry_i" must be asserted when the input is valid
// ------------------------------------------------------------------------------------
// REFERENCES:
//
// Name: A New Non-Restoring Square Root Algorithm and Its VLSI Implementations
// Authors: Yamin Li, Wanming Chu  
// Link: https://ieeexplore.ieee.org/abstract/document/563604   
// ------------------------------------------------------------------------------------
// KEYWORDS : data_register, state_register, counter, next_state_logic, valid_register
// ------------------------------------------------------------------------------------
// DEPENDENCIES: 
// ------------------------------------------------------------------------------------
// PARAMETERS
//
// PARAM NAME : RANGE : DESCRIPTION        : DEFAULT VALUE
// ------------------------------------------------------------------------------------
// DATA_WIDTH :   /   : I/0 number of bits : 32
// ------------------------------------------------------------------------------------

module non_restoring_square_root #(parameter DATA_WIDTH = 32)
(
  input  logic                          clk_i,    
  input  logic                          clk_en_i,
  input  logic                          rst_n_i,    
  input  logic                          valid_entry_i,
  input  logic [DATA_WIDTH - 1:0]       radicand_i,

  output logic [(DATA_WIDTH / 2) - 1:0] root_o,     
  output logic [(DATA_WIDTH / 2):0]     remainder_o,  
  output logic                          data_valid_o
);

//------------//
// PARAMETERS //
//------------//

  // Number of iterations that this module has to perform to return a valid value
  localparam ITERATIONS = (DATA_WIDTH) / 2;

  // Current and next 
  localparam CRT = 0;
  localparam NXT = 1;

//----------------//
// DATA REGISTERS //
//----------------//

  logic [NXT:CRT][DATA_WIDTH - 1:0] root;           
  logic [NXT:CRT][DATA_WIDTH:0] remainder;     
  logic [NXT:CRT][DATA_WIDTH - 1:0] radicand;   
   
      always_ff @(posedge clk_i) begin : data_register
        if (!rst_n_i) begin 
          root[CRT] <= 0;
          remainder[CRT] <= 0;
          radicand[CRT] <= 0;
        end else if (clk_en_i) begin 
          root[CRT] <= root[NXT];
          remainder[CRT] <= remainder[NXT];
          radicand[CRT] <= radicand[NXT];
        end
      end : data_register

//-----------//
// FSM LOGIC //
//-----------//
 
  typedef enum logic [1:0] {IDLE, SQRT, RESTORING} fsm_state_e;

  // IDLE: The unit is waiting for data
  // SQRT: Perform the square root
  // RESTORING: Restore the result

  fsm_state_e [NXT:CRT] state;

  logic [NXT:CRT][$clog2(ITERATIONS) - 1:0] counter;

  // Delay the reset signals by 1 cycle because the FSM should
  // stay 2 cycles in the IDLE stage when resetted
  logic rst_n_dly;  

      always_ff @(posedge clk_i) begin
        rst_n_dly <= rst_n_i;
      end

      always_ff @(posedge clk_i) begin : state_register
        if (!rst_n_i) begin 
          state[CRT] <= IDLE; 
        end else if (clk_en_i) begin 
          state[CRT] <= state[NXT]; 
        end
      end : state_register

      always_ff @(posedge clk_i) begin : counter
        if (!rst_n_i) begin 
          counter[CRT] <= ITERATIONS - 1;
        end else if (clk_en_i) begin
          counter[CRT] <= counter[NXT]; 
        end
      end : counter

  logic [$clog2(ITERATIONS):0] counter_2;   

  // Counter * 2
  assign counter_2 = counter << 1;

  logic [DATA_WIDTH:0] rem_new;

      always_comb begin : next_state_logic
        // Default values
        state[NXT] = state[CRT];
        counter[NXT] = counter[CRT];
        root[NXT] = root[CRT];
        remainder[NXT] = remainder[CRT];

        case (state[CRT])
          IDLE: begin      
                  state[NXT] = (~rst_n_dly) ? IDLE : SQRT;

                  // Load the values with their initial value
                  counter[NXT] = ITERATIONS - 1;
                  radicand[NXT] = radicand_i;
                  root[NXT] = 'b0;
                  remainder[NXT] = 'b0;
                end

          SQRT: begin 
                  state[NXT] = (counter == 'b0) ? RESTORING : SQRT;  
                  counter[NXT] = counter[CRT] - 1;
                  
                  // If the remainder is negative
                  if (remainder[CRT][DATA_WIDTH]) begin 
                    rem_new = (remainder[CRT] << 2) | ((radicand_out >> counter_2) & 'd3);

                    remainder[NXT] = rem_new + ((root[CRT] << 2) | 'd3);               
                  end else begin 
                    rem_new = (remainder[CRT] << 2) | ((radicand_out >> counter_2) & 'd3);

                    remainder[NXT] = rem_new - ((root[CRT] << 2) | 'b1);
                  end

                  // If the remainder is negative
                  if (remainder[NXT][DATA_WIDTH]) begin
                    root[NXT] = (root[CRT] << 1);
                  end else begin
                    root[NXT] = (root[CRT] << 1) | 'b1;
                  end
                end

          RESTORING:  begin
                        state[NXT] = IDLE;
                        remainder[NXT] = remainder_rest;
                      end
        endcase
      end : next_state_logic

//-----------------//
// RESTORING LOGIC //
//-----------------//

  logic signed [DATA_WIDTH:0] remainder_rest;

  assign remainder_rest = remainder[CRT][DATA_WIDTH] ? (remainder[CRT] + ((root[CRT] << 1'b1) | 'b1)) : remainder[CRT];

//--------------//
// OUTPUT LOGIC //
//--------------//

  logic [CRT:NXT] valid_entry;
  
  // If not in state IDLE recycle the current value
  assign valid_entry[NXT] = (state[CRT] == IDLE) ? valid_entry_i : valid_entry[CRT];

      always_ff @(posedge clk_i) begin : valid_register
        if (!rst_n_i) begin 
          valid_entry[CRT] <= 'b0;
        end else if (clk_en_i) begin 
          valid_entry[CRT] <= valid_entry[NXT];
        end
      end : valid_register

  assign data_valid_o = (state[CRT] == IDLE) & valid_entry[CRT];

  assign remainder_o = remainder[CRT];

  assign root_o = root[CRT];
  
endmodule : non_restoring_square_root