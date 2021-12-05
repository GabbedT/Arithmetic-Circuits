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
// --------------------------------------------------------------------------------
// FILE NAME : multiplier_tb.sv
// DEPARTMENT : 
// AUTHOR : Gabriele Tripi
// AUTHOR'S EMAIL : tripi.gabriele2002@gmail.com
// --------------------------------------------------------------------------------
// RELEASE HISTORY
// VERSION : 1.0 
// DESCRIPTION : Generic and expandable testbench for a multiplier. To change / add 
//               a module just add a parameter called with the multiplier's name 
//               (es. BOOTH), modify the if-else statement by adding the DUT and
//               the parameter. Change MUL_TYPE to select a specific DUT. Change
//               SIGNED_MODE accordingly (BOOTH works only on signed values thus
//               SIGNED_MODE = 1). Set the latency accordingly to your module.
// --------------------------------------------------------------------------------
// KEYWORDS :
// --------------------------------------------------------------------------------
// DEPENDENCIES : BitVector.sv
// --------------------------------------------------------------------------------
// PARAMETERS
// PARAM NAME        : RANGE   : DESCRIPTION                   : DEFAULT 
// --------------------------------------------------------------------------------
// SIGNED_MODE       :  [0:1]  : Operate on sign/unsign values : 1
// DATA_WIDTH        :    /    : I/O number of bits            : 32
// ENABLE_CONSTRAINT :  [0:1]  : Enable constraint on inputs   : 0
// TEST_NUMBER       :    /    : Number of test to execute     : 1000
// CLK_CYCLE         :    /    : Clock cycle                   : 10
// LATENCY           :    /    : Cycles until valid output     : ?
// --------------------------------------------------------------------------------

`timescale 1ns/1ps

module multiplier_tb ();

////////////////////////  
// MODULES PARAMETERS //
////////////////////////

  // Booth multiplier
  localparam BOOTH = 0;
  localparam RADIX = 16;

//////////////////////////
// TESTBENCH PARAMETERS //
//////////////////////////
  
  // Change this value based on the type of multiplier
  localparam SIGNED_MODE = 1;

  // Enable contraint on test input
  localparam ENABLE_CONSTRAINT = 0;

  // Number of tests performed
  localparam TEST_NUMBER = 1000;

  // Operand's number of bits
  localparam DATA_WIDTH = 32;

  // In nanoseconds
  localparam CLK_CYCLE = 10;

  // Latency of the multiplier
  // How many cycles until a valid output is produced
  // It is dependent on the multiplier
  localparam LATENCY = 9;

  // Select the DUT
  localparam MUL_TYPE = BOOTH;

  //////////////
  // DUT Nets //
  //////////////

  // Inputs
  logic [DATA_WIDTH - 1:0]       operand_A_i;
  logic [DATA_WIDTH - 1:0]       operand_B_i;
  logic                          clk_i;
  logic                          clk_en_i;
  logic                          rst_n_i;
  logic                          valid_entry_i;

  // Outputs
  logic [(2 * DATA_WIDTH) - 1:0] result_o;
  logic                          data_valid_o;
  logic                          busy_o;


  if (MUL_TYPE == BOOTH)
    begin 
      booth_multiplier dut (.*);
    end

  // Create two object used to simulate the 
  // wanted behaviour of the adder
  BitVector #(DATA_WIDTH) item_1 = new ();
  BitVector #(DATA_WIDTH) item_2 = new ();

  int testPassed = 0;
  int testError = 0;

////////////////////
// TESTBENCH BODY //
////////////////////

      // Generate clock
      always #(CLK_CYCLE / 2) clk_i <= !clk_i; 
      
      // Initial values
      initial begin
        clk_i = 0;
        operand_A_i = 0;
        operand_B_i = 0;
        clk_en_i = 0;
        rst_n_i = 0;
        valid_entry_i = 0;
        
        // Set boundaries
        item_1.setMaxValue(0);
        item_2.setMaxValue(0);
        item_1.setMinValue(0);
        item_2.setMinValue(0);
        
        // Constraint enable
        item_1.limit.constraint_mode(ENABLE_CONSTRAINT);
        item_2.limit.constraint_mode(ENABLE_CONSTRAINT);
      end

      initial begin
        rst_n_i = 1;
        clk_en_i = 1;
        valid_entry_i = 1;
        
        #(0.5);

        for (int i = 0; i < TEST_NUMBER; i++) 
          begin              
            // Check the result when the data is valid (compare the DUT with the golden model)
            if (SIGNED_MODE == 1)
              begin
                // Check on the posedge to capture the right values
                @(posedge data_valid_o)
                assert (result_o == item_1.sMul(item_2.getData())) 
                  begin 
                    testPassed++;
                  end
                else
                  begin 
                    $display("Input 1: ");
                    item_1.printSignedData("D");
                    $display("Input 2: ");
                    item_2.printSignedData("D");
            
                    $display("TEST %0d NOT PASSED AT TIME: %0t ns \n VALUE: %0h \n EXPECTED: %0h \n\n", i, $time, result_o, item_1.sMul(item_2.getData()));
                    testError++;
                  end
              end
            else 
              begin
                // Check on the posedge to capture the right values
                @(posedge data_valid_o)
                assert (result_o == item_1.uMul(item_2.getData())) 
                  begin 
                    testPassed++;
                  end
                else
                  begin 
                    $display("Input 1: ");
                    item_1.printUnsignedData("D");
                    $display("Input 2: ");
                    item_2.printUnsignedData("D");
            
                    $display("TEST %0d NOT PASSED AT TIME: %0t ns \n VALUE: %0h \n EXPECTED: %0h \n\n", i, $time, result_o, item_1.uMul(item_2.getData()));
                    testError++;
                  end
              end

            // Randomize the objects
            item_1.randomize();
            item_2.randomize();

            // Assign the randomized value to the inputs
            operand_A_i = item_1.getData();
            operand_B_i = item_2.getData();
            
            // Wait the cycle before the output is valid
            @(negedge busy_o);
                      
          end
        
        $display("T = [%0t ns]", $time());
        
        // Display the final result of the testbench
        $display("[TESTBENCH COMPLETED] \n Number of test passed: %0d \n Number of test failed: %0d", testPassed, testError);

        $stop();
      end
endmodule
