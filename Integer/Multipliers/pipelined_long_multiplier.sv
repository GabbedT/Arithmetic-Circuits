module pipelined_long_multiplier #(

    /* Number of bits in a word */
    parameter DATA_WIDTH = 16,

    /* Number of pipeline stages */
    parameter PIPELINE_DEPTH = 4
) (
    input  logic                          clk_i,
    input  logic                          clk_en_i,
    input  logic                          rst_n_i,
    input  logic [DATA_WIDTH - 1:0]       operand_A_i,
    input  logic [DATA_WIDTH - 1:0]       operand_B_i,
    input  logic                          valid_entry_i,

    output logic [(2 * DATA_WIDTH) - 1:0] result_o,
    output logic                          data_valid_o
);

//--------------//
//  PARAMETERS  //
//--------------//

    /* Partial products elaborated per clock cycle*/
    localparam PRODUCT_PER_STAGE = DATA_WIDTH / PIPELINE_DEPTH;

    /* Number of pipeline registers */
    localparam PIPELINE_REG = PIPELINE_DEPTH - 1;

    /* Result number of bits */
    localparam RESULT_WIDTH = 2 * DATA_WIDTH;


//----------------------//
//  PIPELINE REGISTERS  //
//----------------------//

    logic [PIPELINE_REG - 1:0][DATA_WIDTH - 1:0] operand_A_stage_in, operand_A_stage_out, operand_B_stage_in, operand_B_stage_out;

    logic [PIPELINE_REG - 1:0] data_valid_stage_in, data_valid_stage_out, carry_stage_in, carry_stage_out;

    logic [PIPELINE_REG - 1:0][DATA_WIDTH - 2:0] partial_product_stage_in, partial_product_stage_out;


        /* Input assignment */
        always_comb begin : pipeline_assignment
            for (int i = 0; i < PIPELINE_REG; ++i) begin 
                if (i == 0) begin
                    operand_A_stage_in[0] = operand_A_i;
                    operand_B_stage_in[0] = operand_B_i;

                    data_valid_stage_in[0] = valid_entry_i;
                end else begin
                    operand_A_stage_in[i] = operand_A_stage_out[i - 1];
                    operand_B_stage_in[i] = operand_B_stage_out[i - 1];

                    data_valid_stage_in[i] = data_valid_stage_out[i - 1];
                end
            end
        end : pipeline_assignment

        always_ff @(posedge clk_i or negedge rst_n_i) begin : pipeline_registers
            if (!rst_n_i) begin
                for (int i = 0; i < PIPELINE_REG; ++i) begin 
                    operand_A_stage_out[i] <= 'b0;
                    operand_B_stage_out[i] <= 'b0;
                    data_valid_stage_out[i] <= 1'b0;
                    carry_stage_out[i] <= 1'b0;
                    partial_product_stage_out[i] <= 'b0;
                end
            end else if (clk_en_i) begin
                for (int i = 0; i < PIPELINE_REG; ++i) begin 
                    operand_A_stage_out[i] <= operand_A_stage_in[i];
                    operand_B_stage_out[i] <= operand_B_stage_in[i];
                    data_valid_stage_out[i] <= data_valid_stage_in[i];
                    carry_stage_out[i] <= carry_stage_in[i];
                    partial_product_stage_out[i] <= partial_product_stage_in[i];
                end  
            end
        end : pipeline_registers


    logic [PIPELINE_REG - 1:0][PRODUCT_PER_STAGE - 1:0] result_bits;

    logic [PIPELINE_REG - 1:0][PIPELINE_REG - 1:0][PRODUCT_PER_STAGE - 1:0] result_bits_stage;


        always_ff @(posedge clk_i or negedge rst_n_i) begin
            if (!rst_n_i) begin
                for (int i = 0; i < PIPELINE_REG; ++i) begin
                    for (int j = i; j < PIPELINE_REG; ++j) begin
                        result_bits_stage[i][j] <= 'b0;
                    end
                end
            end else if (clk_en_i) begin
                for (int i = 0; i < PIPELINE_REG; ++i) begin
                    for (int j = i; j < PIPELINE_REG; ++j) begin
                        if (i == j) begin 
                            result_bits_stage[i][j] <= result_bits[i];
                        end else begin 
                            result_bits_stage[i][j] <= result_bits_stage[i][j - 1];
                        end
                    end
                end
            end
        end


//------------//
//  DATAPATH  //
//------------//

    genvar i;
    generate 
        for (i = 0; i < PIPELINE_DEPTH; ++i) begin
            if (i == 0) begin 
                pipelined_long_multiplier_stage #(DATA_WIDTH, PRODUCT_PER_STAGE) pipeline_stage (
                    .operand_A_i         ( operand_A_i                          ),
                    .operand_B_i         ( operand_B_i[PRODUCT_PER_STAGE - 1:0] ),
                    .last_partial_prod_i ( 'b0                                  ),
                    .carry_i             ( 1'b0                                 ),
                    .carry_o             ( carry_stage_in[0]                    ),
                    .partial_product_o   ( partial_product_stage_in[0]          ),
                    .final_result_bits_o ( result_bits[0]            )
                );
            end else if (i == (PIPELINE_DEPTH - 1)) begin
                pipelined_long_multiplier_stage #(DATA_WIDTH, PRODUCT_PER_STAGE) pipeline_stage (
                    .operand_A_i         ( operand_A_stage_out[i - 1]                                               ),
                    .operand_B_i         ( operand_B_stage_out[i - 1][(PRODUCT_PER_STAGE * i) +: PRODUCT_PER_STAGE] ),
                    .last_partial_prod_i ( partial_product_stage_out[i - 1]                                         ),
                    .carry_i             ( carry_stage_out[i - 1]                                                   ),
                    .carry_o             ( result_o[RESULT_WIDTH - 1]                                               ),
                    .partial_product_o   ( result_o[RESULT_WIDTH - 2:DATA_WIDTH]                                    ),
                    .final_result_bits_o ( result_o[DATA_WIDTH - 1:DATA_WIDTH - PRODUCT_PER_STAGE]                  )
                );     
            end else begin
                pipelined_long_multiplier_stage #(DATA_WIDTH, PRODUCT_PER_STAGE) pipeline_stage (
                    .operand_A_i         ( operand_A_stage_out[i - 1]                                               ),
                    .operand_B_i         ( operand_B_stage_out[i - 1][(PRODUCT_PER_STAGE * i) +: PRODUCT_PER_STAGE] ),
                    .last_partial_prod_i ( partial_product_stage_out[i - 1]                                         ),
                    .carry_i             ( carry_stage_out[i - 1]                                                   ),
                    .carry_o             ( carry_stage_in[i]                                                        ),
                    .partial_product_o   ( partial_product_stage_in[i]                                              ),
                    .final_result_bits_o ( result_bits[i]                                                           )
                );
            end
        end
    endgenerate


//---------------------//
//  OUTPUT ASSIGNMENT  //
//---------------------//

    assign data_valid_o = data_valid_stage_out[PIPELINE_REG - 1];


    logic [DATA_WIDTH - PRODUCT_PER_STAGE - 1:0] result;
    
        /* Assign to result the last stage of the result bits */
        always_comb begin 
            for (int i = 0; i < PIPELINE_REG; ++i) begin 
                result[i * PRODUCT_PER_STAGE +: PRODUCT_PER_STAGE] = result_bits_stage[i][PIPELINE_REG - 1];
            end
        end

    assign result_o[DATA_WIDTH - PRODUCT_PER_STAGE - 1:0] = result;

endmodule : pipelined_long_multiplier
