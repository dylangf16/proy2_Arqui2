//------------------------------------------------------------------------------
// Module: PE_SW (CORRECTED - Systolic Array Version)
// Descripción: Elemento de procesamiento para arreglo sistólico que:
// 1. Multiplica A_in * B_in y acumula en psum_reg
// 2. Propaga A_in y B_in a los vecinos con 1 ciclo de delay
// 3. La acumulación se realiza cuando ambos A_in y B_in son != 0
//------------------------------------------------------------------------------
module PE_SW #(
    parameter DATA_WIDTH = 16,   // ancho de datos de A y B
    parameter ACC_WIDTH  = 32    // ancho del acumulador psum
)(
    input  logic                       clk,
    input  logic                       rst_n,      // reset activo-bajo
    // entradas de este ciclo
    input  logic signed [DATA_WIDTH-1:0] A_in,
    input  logic signed [DATA_WIDTH-1:0] B_in,
    input  logic signed [ACC_WIDTH -1:0] psum_in,  // no usado en esta implementación
    // salidas hacia los vecinos (disponibles el siguiente ciclo)
    output logic signed [DATA_WIDTH-1:0] A_out,
    output logic signed [DATA_WIDTH-1:0] B_out,
    output logic signed [ACC_WIDTH -1:0] psum_out
);

    // registros internos para retener A, B y psum
    logic signed [DATA_WIDTH-1:0] A_reg, B_reg;
    logic signed [ACC_WIDTH -1:0] psum_reg;

    // Lógica secuencial: en cada flanco de reloj
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            A_reg    <= '0;
            B_reg    <= '0;
            psum_reg <= '0;
        end else begin
            // Propagar A y B a los vecinos (con delay de 1 ciclo)
            A_reg <= A_in;
            B_reg <= B_in;
            
            // Acumular solo cuando tenemos datos válidos (ambos != 0)
            // Esto es crucial para el funcionamiento correcto del arreglo sistólico
            if (A_in != 0 && B_in != 0) begin
                psum_reg <= psum_reg + (A_in * B_in);
            end
        end
    end

    // Salidas: datos propagados y acumulador
    assign A_out    = A_reg;
    assign B_out    = B_reg;
    assign psum_out = psum_reg;

endmodule