//------------------------------------------------------------------------------
// Module: SystolicArray8x8
// Descripción: Arreglo sistólico 8x8 con control de habilitación apropiado
// - Acepta matrices A y B pre-cargadas
// - Control explícito de start/done
// - Alimentación correcta con skew temporal
//------------------------------------------------------------------------------
module SystolicArray8x8 #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH  = 32
)(
    input  logic                                  clk,
    input  logic                                  rst_n,
    input  logic                                  start,           // Iniciar computación
    
    // Matrices de entrada (pre-cargadas)
    input  logic signed [DATA_WIDTH-1:0]          A_matrix [0:7][0:7],
    input  logic signed [DATA_WIDTH-1:0]          B_matrix [0:7][0:7],
    
    // Resultados y control
    output logic signed [ACC_WIDTH -1:0]          C_out [0:7][0:7],
    output logic                                  done
);

    // Señales internas del arreglo
    logic signed [DATA_WIDTH-1:0] A_internal [0:7][0:7];
    logic signed [DATA_WIDTH-1:0] B_internal [0:7][0:7];
    logic signed [ACC_WIDTH -1:0] psum_internal [0:7][0:7];
    
    // Alimentación de datos al arreglo
    logic signed [DATA_WIDTH-1:0] A_feed [0:7];
    logic signed [DATA_WIDTH-1:0] B_feed [0:7];
    
    // Control de temporización
    logic [4:0] cycle_counter;  // 0-23 para 24 ciclos
    logic       computing;
    logic       enable_array;
    
    // Máquina de estados de control
    typedef enum logic [1:0] {
        IDLE,
        COMPUTE,
        DRAIN,
        COMPLETE
    } compute_state_t;
    
    compute_state_t state;
    
    // Control de la computación
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_counter <= 5'b0;
            computing <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        cycle_counter <= 5'b0;
                        computing <= 1'b1;
                    end
                end
                
                COMPUTE: begin
                    if (cycle_counter < 5'd15) begin  // 16 ciclos de alimentación (0-15)
                        cycle_counter <= cycle_counter + 1;
                    end else begin
                        state <= DRAIN;
                        cycle_counter <= 5'b0;
                    end
                end
                
                DRAIN: begin
                    if (cycle_counter < 5'd7) begin   // 8 ciclos de drenaje (0-7)
                        cycle_counter <= cycle_counter + 1;
                    end else begin
                        state <= COMPLETE;
                        computing <= 1'b0;
                        done <= 1'b1;
                    end
                end
                
                COMPLETE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Habilitación del arreglo (solo durante COMPUTE)
    assign enable_array = (state == COMPUTE);
    
    // Alimentación de datos con skew apropiado
    always_comb begin
        // Inicializar con ceros
        for (int i = 0; i < 8; i++) begin
            A_feed[i] = 16'b0;
            B_feed[i] = 16'b0;
        end
        
        if (state == COMPUTE) begin
            // Alimentar datos con el skew correcto para arreglo sistólico
            for (int i = 0; i < 8; i++) begin
                for (int k = 0; k < 8; k++) begin
                    // A: fila i, elemento k, disponible en ciclo i+k
                    if (cycle_counter == (i + k) && k < 8) begin
                        A_feed[i] = A_matrix[i][k];
                    end
                    
                    // B: elemento k, columna i, disponible en ciclo i+k  
                    if (cycle_counter == (i + k) && k < 8) begin
                        B_feed[i] = B_matrix[k][i];
                    end
                end
            end
        end
    end
    
    // Instanciación de los PEs
    genvar i, j;
    generate
        for (i = 0; i < 8; i = i + 1) begin : ROWS
            for (j = 0; j < 8; j = j + 1) begin : COLS
                PE_SO #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH (ACC_WIDTH)
                ) pe_inst (
                    .clk    (clk),
                    .rst_n  (rst_n),
                    .enable (enable_array),
                    .A_in   ( (j == 0) ? A_feed[i] : A_internal[i][j-1] ),
                    .B_in   ( (i == 0) ? B_feed[j] : B_internal[i-1][j] ),
                    .psum_in( '0 ),
                    .A_out  ( A_internal[i][j] ),
                    .B_out  ( B_internal[i][j] ),
                    .psum_out( psum_internal[i][j] )
                );
            end
        end
    endgenerate
    
    // Asignación de resultados
    generate
        for (i = 0; i < 8; i = i + 1) begin : OUTPUT_ROWS
            for (j = 0; j < 8; j = j + 1) begin : OUTPUT_COLS
                assign C_out[i][j] = psum_internal[i][j];
            end
        end
    endgenerate

endmodule