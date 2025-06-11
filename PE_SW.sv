//------------------------------------------------------------------------------
// Module: PE_SW (con ReLU opcional)
//------------------------------------------------------------------------------
module PE_SW #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH  = 32,
    parameter ACTIVATE   = 1    // 1 = aplicar ReLU, 0 = bypass (pusm)
)(
    input  logic                       clk,
    input  logic                       rst_n,
    input  logic signed [DATA_WIDTH-1:0] A_in,
    input  logic signed [DATA_WIDTH-1:0] B_in,
    output logic signed [DATA_WIDTH-1:0] A_out,
    output logic signed [DATA_WIDTH-1:0] B_out,
    // Valor antes de la activación (solo para debug/monitor)
    output logic signed [ACC_WIDTH -1:0] pre_act,
    // Valor tras ReLU (o mismo psum si ACTIVATE=0)
    output logic signed [ACC_WIDTH -1:0] psum_out
);

    // Registros internos
    logic signed [DATA_WIDTH-1:0]      A_reg, B_reg;
    logic signed [ACC_WIDTH -1:0]      psum_reg;

    // Pipeline: registro de A, B y acumulador
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            A_reg    <= '0;
            B_reg    <= '0;
            psum_reg <= '0;
        end else begin
            A_reg    <= A_in;
            B_reg    <= B_in;
            psum_reg <= psum_reg + A_reg * B_reg;
        end
    end

    // Desplazamiento de datos a vecinos
    assign A_out   = A_reg;
    assign B_out   = B_reg;
    // Exponer psum crudo
    assign pre_act = psum_reg;

    // Activación ReLU (o bypass)
    generate
      if (ACTIVATE) begin
        // ReLU: max(0, psum_reg)
        assign psum_out = (pre_act < 0) ? '0 : pre_act;
      end else begin
        // Bypass: el mismo valor acumulado
        assign psum_out = pre_act;
      end
    endgenerate

endmodule
