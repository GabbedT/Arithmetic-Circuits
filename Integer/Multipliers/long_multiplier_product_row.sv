module long_multiplier_product_row #(

    /* Number of bits in a word */
    parameter DATA_WIDTH = 32
) (
    input  logic [DATA_WIDTH - 1:0] and_product_i,
    input  logic [DATA_WIDTH - 2:0] partial_product_i,
    input  logic                    prev_carry_i,

    output logic [DATA_WIDTH - 2:0] result_o,
    output logic                    product_bit_o,
    output logic                    carry_o
);

//------------//
//  DATAPATH  //
//------------//

    /* Second last adder carry out */
    logic carry;

    assign {carry, result_o[DATA_WIDTH - 3:0], product_bit_o} = and_product_i[DATA_WIDTH - 2:0] + partial_product_i[DATA_WIDTH - 2:0];

    /* Last output bit logic */
    assign {carry_o, result_o[DATA_WIDTH - 2]} = prev_carry_i + carry + and_product_i[DATA_WIDTH - 1];

endmodule : long_multiplier_product_row