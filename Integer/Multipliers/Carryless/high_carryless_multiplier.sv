`ifndef HIGH_CARRYLESS_MULTIPLIER 
    `define HIGH_CARRYLESS_MULTIPLIER

module high_carryless_multiplier #(

    /* Input & Output number of bits */
    parameter DATA_WIDTH = 32
) (
    input  logic [DATA_WIDTH - 1:0] operand_A_i,
    input  logic [DATA_WIDTH - 1:0] operand_B_i,
    output logic [DATA_WIDTH - 1:0] result_high_o
);

    logic [DATA_WIDTH - 1:0] result, result_next;

        always_comb begin 
            /* Default values */
            result_next = '0;
            result = '0;

            for (int i = 1; i < DATA_WIDTH; ++i) begin
                if ((operand_B_i >> i) & 32'b1) begin
                    result = result_next ^ (operand_A_i >> (DATA_WIDTH - i));
                end else begin
                    result = result_next; 
                end

                result_next = result;
            end
        end 

    assign result_high_o = result;

endmodule : high_carryless_multiplier

`endif 