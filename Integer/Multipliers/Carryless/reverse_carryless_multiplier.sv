`ifndef REVERSE_CARRYLESS_MULTIPLIER 
    `define REVERSE_CARRYLESS_MULTIPLIER

module reverse_carryless_multiplier #(

    /* Input & Output number of bits */
    parameter DATA_WIDTH = 32
) (
    input  logic [DATA_WIDTH - 1:0] operand_A_i,
    input  logic [DATA_WIDTH - 1:0] operand_B_i,
    output logic [DATA_WIDTH - 1:0] result_o
);

    logic [DATA_WIDTH - 1:0] result, result_next;

        always_comb begin 
            /* Default values */
            result_next = '0;
            result = '0;

            for (int i = 0; i < (DATA_WIDTH - 1); ++i) begin
                if ((operand_B_i >> i) & 32'b1) begin
                    result = result_next ^ (operand_A_i >> (DATA_WIDTH - i - 1));
                end else begin
                    result = result_next; 
                end

                result_next = result;
            end
        end 

    assign result_o = result;

endmodule : reverse_carryless_multiplier

`endif 