//------------------------------------------------------------------------------
// Module: SystolicArray8x8 (con ReLU en cada PE)
//------------------------------------------------------------------------------ 
module SystolicArray8x8 #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH  = 32
)(
    input  logic                                  clk,
    input  logic                                  rst_n,
    input  logic signed [DATA_WIDTH-1:0]          A_in   [0:7],  // flujo desde la izquierda
    input  logic signed [DATA_WIDTH-1:0]          B_in   [0:7],  // flujo desde arriba
    // Salida opcional para debug: valor antes de la ReLU
    output logic signed [ACC_WIDTH -1:0]          pre_act[0:7][0:7],
    // Salida final tras aplicar ReLU
    output logic signed [ACC_WIDTH -1:0]          C_out  [0:7][0:7]
);

    // Buses internos de A y B para el desplazamiento
    logic signed [DATA_WIDTH-1:0] A_bus_out [0:7][0:7];
    logic signed [DATA_WIDTH-1:0] B_bus_out [0:7][0:7];
    // Bus de acumulaciones tras activación
    logic signed [ACC_WIDTH -1:0] psum_bus   [0:7][0:7];

    genvar i, j;
    generate
        for (i = 0; i < 8; i = i + 1) begin : ROWS
            for (j = 0; j < 8; j = j + 1) begin : COLS

                PE_SW #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH (ACC_WIDTH),
                    .ACTIVATE  (1)            // habilita ReLU
                ) pe_inst (
                    .clk     (clk),
                    .rst_n   (rst_n),
                    .A_in    ((j == 0) ? A_in[i]       : A_bus_out[i][j-1]),
                    .B_in    ((i == 0) ? B_in[j]       : B_bus_out[i-1][j]),
                    .A_out   (A_bus_out[i][j]),
                    .B_out   (B_bus_out[i][j]),
                    .pre_act (pre_act   [i][j]),      // debug: antes de ReLU
                    .psum_out(psum_bus  [i][j])       // tras ReLU
                );

                // Conectar la salida final
                assign C_out[i][j] = psum_bus[i][j];

            end
        end
    endgenerate

endmodule
