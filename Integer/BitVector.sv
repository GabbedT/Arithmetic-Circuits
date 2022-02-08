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
// -----------------------------------------------------------------------------
// FILE NAME : BitVector.sv
// DEPARTMENT : 
// AUTHOR : Gabriele Tripi
// AUTHOR'S EMAIL : tripi.gabriele2002@gmail.com
// -----------------------------------------------------------------------------
// RELEASE HISTORY
// VERSION : 1.0 
// DATE : 05 / 10 / 2021
// DESCRIPTION : This class collect various methods and tasks that can be used
//               on bit vectors. The vectors are immutable in terms of number
//               of bits. Once the object is created it's length cannot be 
//               modified.
// -----------------------------------------------------------------------------
// KEYWORDS : Class
// -----------------------------------------------------------------------------
// PARAMETERS
// PARAM NAME  : RANGE   : DESCRIPTION    : DEFAULT 
// DATA_WIDTH  :    /    : Number of bits : 32
// -----------------------------------------------------------------------------

class BitVector #(parameter DATA_WIDTH = 32);
  
  localparam BYTE_NUMBER = DATA_WIDTH / 8;
  
  typedef struct packed {
      bit [3:0] nibble_high;
      bit [3:0] nibble_low;
  } byte_t;
  
  rand byte_t [BYTE_NUMBER - 1:0] data;
   
  byte_t [BYTE_NUMBER - 1:0] maxValue = 'b1;
  byte_t [BYTE_NUMBER - 1:0] minValue = 'b1;
  
  constraint limit {data inside {[maxValue:minValue]};}
  
//-------------//
// CONSTRUCTOR //
//-------------//
  
  // Initialize the data
  function new ();
    this.data = 0;
  endfunction 
  
//-------------//
// GET METHODS //
//-------------//

  // Variables are declared "public", so in the testbench you can have a 
  // free access to them without using necessarily these methods. 
  
  // Return the entire bit vector
  function bit [DATA_WIDTH - 1:0] getData ();
    return data;
  endfunction
  
  // Return a specific byte of the bit vector
  // Parameter "byteIdx" is ranged from 0 to (DATA_WIDTH / 8) - 1
  function bit [7:0] getByte (input int byteIdx);    
    if (byteIdx * 8 > DATA_WIDTH)
      begin 
        $display("Out of range!");
      end
    else 
      begin 
        return data[byteIdx];
      end     
  endfunction
  
  // Return a specific nibble of the bit vector 
  // Parameter "byteIdx" is ranged from 0 to (DATA_WIDTH / 8) - 1
  // Parameter "nibbleIdx" is ranged from 0 (low nibble) to 1 (high nibble)
  function bit [3:0] getNibble (input int byteIdx, input bit nibbleIdx);
    if (byteIdx * 8 > DATA_WIDTH)
      begin 
        $display("Out of range!");
      end
    else 
      begin 
        if (nibbleIdx)
          begin
            return data[byteIdx].nibble_high;
          end
        else 
          begin
            return data[byteIdx].nibble_low;
          end
      end 
  endfunction
  
  // Return the actual vector length
  function int length ();
    return DATA_WIDTH;
  endfunction
  
  function bit [DATA_WIDTH - 1:0] getMaxValue ();
    return maxValue;
  endfunction
  
  function bit [DATA_WIDTH - 1:0] getMinValue ();
    return minValue;
  endfunction
  
//-------------//
// SET METHODS //
//-------------//

  // Variables are declared "public", so in the testbench you can have a 
  // free access to them without using necessarily these methods. 

  // Max Value constraint. The input must be equal to DATA_WIDTH
  function void setMaxValue (input bit [DATA_WIDTH - 1:0] maxValue);
    this.maxValue = maxValue;
  endfunction

  // Min Value constraint. The input must be equal to DATA_WIDTH
  function void setMinValue (input bit [DATA_WIDTH - 1:0] minValue);
    this.minValue = minValue;
  endfunction
  
  // Set the entire vector
  function void setData (input bit [DATA_WIDTH - 1:0] data);
    this.data = data;
  endfunction
  
  // Set a specific vector's byte
  // Parameter "byteIdx" is ranged from 0 to (DATA_WIDTH / 8) - 1
  function void setByte (input int byteIdx, input logic [7:0] byte_i);  
    if (byteIdx * 8 > DATA_WIDTH)
      begin 
        $display("Out of range!");
      end
    else 
      begin 
        data[byteIdx] = byte_i;
      end 
  endfunction
  
  // Set a specific vector's nibble
  // Parameter "byteIdx" is ranged from 0 to (DATA_WIDTH / 8) - 1
  // Parameter "nibbleIdx" is ranged from 0 (low nibble) to 1 (high nibble)
  function void setNibble (input int byteIdx, input bit nibbleIdx, input logic [3:0] nibble_i);
    if (nibbleIdx)
      begin
        this.data[byteIdx].nibble_high = nibble_i;
      end
    else
      begin
        this.data[byteIdx].nibble_low = nibble_i;
      end
  endfunction
  
//-------------------//
// COMPARISON METHOD //
//-------------------//
  
  // Return 1 if they are equals else 0
  function bit equals (input logic [DATA_WIDTH - 1:0] vector);
    if (data == vector)
      begin 
        return 1;
      end
    else 
      begin 
        return 0;
      end
  endfunction

  // Return 1 if it's negative else 0 (consider the number as signed)
  function bit isNegative ();
    if (data[DATA_WIDTH - 1])
      begin 
        return 1;
      end
    else 
      begin 
        return 0;
      end
  endfunction

  // Print value formatted, it print the value differently based on the parameter:
  // D => Print decimal
  // H => Print exadecimal
  // O => Print octal
  // B => Print binary
  function void printUnsignedData (input string format);
    if (format.toupper() == "D")
      begin 
        $display("Data: %d \n", this.data);
      end
    else if (format.toupper() == "H")
      begin 
        $display("Data: 0x%0h \n", this.data);
      end
    else if (format.toupper() == "O")
      begin 
        $display("Data: %0o \n", this.data);
      end
    else if (format.toupper() == "B")
      begin 
        $display("Data: %b \n", this.data);
      end
  endfunction 

  function void printSignedData (input string format);
    if (format.toupper() == "D")
      begin 
        $display("Data: %d \n", $signed(this.data));
      end
    else if (format.toupper() == "H")
      begin 
        $display("Data: 0x%0h \n", $signed(this.data));
      end
    else if (format.toupper() == "O")
      begin 
        $display("Data: %0o \n", $signed(this.data));
      end
    else if (format.toupper() == "B")
      begin 
        $display("Data: %b \n", $signed(this.data));
      end
  endfunction

//-----------------------//
// COMPUTATIONAL METHODS //
//-----------------------//

  function bit [DATA_WIDTH - 1:0] add (input bit [DATA_WIDTH - 1:0] data);
    return this.data + data;
  endfunction

  function bit carry (input bit [DATA_WIDTH - 1:0] data);
    bit carry_gen;
    bit [DATA_WIDTH - 1:0] result;
    {carry_gen, result} = this.data + data;

    return carry_gen;
  endfunction

  function bit [DATA_WIDTH - 1:0] sub (input bit [DATA_WIDTH - 1:0] data);
    return this.data - data;
  endfunction

  function bit [DATA_WIDTH - 1:0] sDiv (input bit [DATA_WIDTH - 1:0] data);
    return $signed(this.data) / $signed(data);
  endfunction
  
  function bit [(2 * DATA_WIDTH) - 1:0] sMul (input bit [DATA_WIDTH - 1:0] data);
    return $signed(this.data) * $signed(data);
  endfunction
  
  function bit [(2 * DATA_WIDTH) - 1:0] uMul (input bit [DATA_WIDTH - 1:0] data);
    return this.data * data;
  endfunction

  function bit [DATA_WIDTH - 1:0] twoComplement ();
    return -data;
  endfunction

endclass 