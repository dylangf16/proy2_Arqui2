//------------------------------------------------------------------------------
// Module: PE_SO
// Descripción: Elemento de procesamiento para arreglo sistólico
// - Siempre multiplica y acumula (sin condición de != 0)
// - Propaga A_in y B_in con delay de 1 ciclo
// - Acumulación continua para el funcionamiento sistólico correcto
//------------------------------------------------------------------------------
module PE_SO #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH  = 32
)(
    input  logic                       clk,
    input  logic                       rst_n,
    input  logic                       enable,        // Señal de habilitación
    
    // Entradas de este ciclo
    input  logic signed [DATA_WIDTH-1:0] A_in,
    input  logic signed [DATA_WIDTH-1:0] B_in,
    input  logic signed [ACC_WIDTH -1:0] psum_in,     // No usado en esta implementación
    
    // Salidas hacia los vecinos 
    output logic signed [DATA_WIDTH-1:0] A_out,
    output logic signed [DATA_WIDTH-1:0] B_out,
    output logic signed [ACC_WIDTH -1:0] psum_out
);

    // Registros internos
    logic signed [DATA_WIDTH-1:0] A_reg, B_reg;
    logic signed [ACC_WIDTH -1:0] psum_reg;
    logic signed [DATA_WIDTH*2-1:0] mult_result;

    // Cálculo del producto
    always_comb begin
        mult_result = A_in * B_in;
    end

    // Lógica secuencial
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            A_reg    <= '0;
            B_reg    <= '0;
            psum_reg <= '0;
        end else if (enable) begin
            // Propagar A y B (con delay de 1 ciclo)
            A_reg <= A_in;
            B_reg <= B_in;
            
            // Acumular SIEMPRE cuando está habilitado
            // Esta es la operación clave del arreglo sistólico
            psum_reg <= psum_reg + mult_result;
        end else begin
            // Solo propagar sin acumular cuando está deshabilitado
            A_reg <= A_in;
            B_reg <= B_in;
        end
    end

    // Asignación de salidas
    assign A_out    = A_reg;
    assign B_out    = B_reg;
    assign psum_out = psum_reg;

endmodule