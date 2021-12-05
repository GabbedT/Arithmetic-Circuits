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
// -----------------------------------------------------------------------------
// --------------------------------------------------------------------------------
// FILE NAME : adder_tb.sv
// DEPARTMENT : 
// AUTHOR : Gabriele Tripi
// AUTHOR'S EMAIL : tripi.gabriele2002@gmail.com
// --------------------------------------------------------------------------------
// RELEASE HISTORY
// VERSION : 1.0 
// DATE : 28 / 10 / 2021
// DESCRIPTION : Generic and expandable testbench for an adder, it can be connected 
//               to any adder. To change / add a module just add a parameter called
//               with the adder's name (es. CS_ADDER), modify the if-else statement
//               by adding the DUT and the parameter. Change ADDER_TYPE to select a
//               specific DUT.
// --------------------------------------------------------------------------------
// KEYWORDS :
// --------------------------------------------------------------------------------
// PARAMETERS
// PARAM NAME  : RANGE   : DESCRIPTION               : DEFAULT 
// DATA_WIDTH  :    /    : I/O number of bits        : 32
// TEST_NUMBER :    /    : Number of test to execute : 1000
// CLK_CYCLE   :    /    : Clock cycle               : 10
// --------------------------------------------------------------------------------

`timescale 1ns/1ps

`include "BitVector.sv"

module adder_tb ();

////////////////////////  
// MODULES PARAMETERS //
////////////////////////

  // Ripple Carry Adder
  localparam RC_ADDER = 0;
  // Carry Lookahead Adder
  localparam CLA_ADDER = 1;
  // Carry Skip Adder
  localparam CSK_ADDER = 2;
  // Carry Select Adder
  localparam CSEL_ADDER = 3;

  // Number of bits in a vector
  localparam DATA_WIDTH = 32;

  // Parameter used in modules which calculate the
  // output in blocks of BLOCK_WIDTH bits 
  localparam BLOCK_WIDTH = 4;

//////////////////////////
// TESTBENCH PARAMETERS //
//////////////////////////
  
  // Enable contraint on test input
  localparam ENABLE_CONSTRAINT = 0;

  // Number of tests performed
  localparam TEST_NUMBER = 1000;

  // In nanoseconds
  localparam CLK_CYCLE = 10;

  // Select the DUT
  localparam ADDER_TYPE = CSK_ADDER;

//////////////
// DUT Nets //
//////////////

  // Inputs
  logic [DATA_WIDTH - 1:0] operand_A_i;
  logic [DATA_WIDTH - 1:0] operand_B_i;
  logic                    carry_i;

  // Outputs
  logic [DATA_WIDTH - 1:0] result_o;
  logic                    carry_o;
  
  
  if (ADDER_TYPE == RC_ADDER)
    begin
      ripple_carry_adder dut (.*);
    end
  else if (ADDER_TYPE == CLA_ADDER)
    begin
      carry_lookahead_adder dut (.*);
    end
  else if (ADDER_TYPE == CSK_ADDER)
    begin 
      carry_skip_adder dut (.*);
    end
  else if (ADDER_TYPE == CSEL_ADDER)
    begin 
      carry_select_adder dut (.*);
    end
  
  // Create two object used to simulate the 
  // wanted behaviour of the adder
  BitVector #(DATA_WIDTH) item_1 = new ();
  BitVector #(DATA_WIDTH) item_2 = new ();

  // Variable that hold the expected result, it hold the carry
  logic [DATA_WIDTH:0] result;
  
  int testPassed = 0;
  int testError = 0;

      initial begin 
        operand_A_i = 0;
        operand_B_i = 0;
        carry_i = 0;
        
        // Set boundaries
        item_1.setMaxValue('b1);
        item_2.setMaxValue('b1);
        item_1.setMinValue('b0);
        item_2.setMinValue('b0);
        
        // Constraint enable
        item_1.limit.constraint_mode(ENABLE_CONSTRAINT);
        item_2.limit.constraint_mode(ENABLE_CONSTRAINT);
      end

      initial begin
        for (int i = 0; i < TEST_NUMBER; i++)
          begin 
            // Randomize the objects
            item_1.randomize();
            item_2.randomize();

            // Perform an addition
            if (i < TEST_NUMBER / 2)
              begin 
                // Assign the randomized value to the inputs
                operand_A_i = item_1.data;
                operand_B_i = item_2.data;

                result = item_1.data + item_2.data;

                // Wait 1 clock cycle
                #CLK_CYCLE;

                // Check the result (compare the DUT with the golden model)
                assert ({carry_o, result_o} == result) 
                  begin 
                    testPassed++;
                  end
                else
                  begin 
                    $display("Input 1: ");
                    item_1.printData("D");
                    $display("Input 2: ");
                    item_2.printData("D");

                    $display("TEST %0d NOT PASSED AT TIME: %0t ns \n VALUE: %0d \n EXPECTED: %0d \n\n", i, $time, result_o, item_1.add(item_2.data));
                    testError++;
                  end        
              end
            // Perform a subtraction
            else 
              begin 
                // Assign the randomized value to the inputs
                operand_A_i = item_1.data;
                operand_B_i = item_2.twoComplement();

                result = item_1.data + item_2.data;

                // Wait 1 clock cycle
                #CLK_CYCLE;

                // Check the result (compare the DUT with the golden model)
                assert ({carry_o, result_o} == result) 
                  begin 
                    testPassed++;
                  end
                else 
                  begin  
                    $display("Input 1: ");
                    item_1.printSignedData("D");
                    $display("Input 2: ");
                    item_2.printSignedData("D");

                    $display("TEST %0d NOT PASSED AT TIME: %0t ns \n VALUE: %0d \n EXPECTED: %0d \n\n", i, $time, result_o, item_1.sub(item_2.data));
                    testError++;
                  end
              end      
          end
        
        // Display the final result of the testbench
        $display("[TESTBENCH COMPLETED] \n Number of test passed: %0d \n Number of test failed: %0d", testPassed, testError);

        $finish;
      end

endmodule
