//------------------------------------------------------------------------------
// Testbench corregido: tb_systolic8x8.sv
// Implementa el patrón de inyección correcto para arreglo sistólico
//------------------------------------------------------------------------------

module tb_systolic8x8;

    // Reloj y reset
    logic clk;
    logic rst_n;

    // Entradas al arreglo
    logic signed [15:0] A_in_tb [0:7];
    logic signed [15:0] B_in_tb [0:7];

    // Salidas del arreglo
    logic signed [31:0] C_out_tb [0:7][0:7];

    // Matrices de referencia (declaradas en ámbito de módulo)
    logic signed [15:0] A_matrix [0:7][0:7];
    logic signed [15:0] B_matrix [0:7][0:7];
    logic signed [31:0] C_ref     [0:7][0:7];

    // Variables de conteo
    integer i, j, t, k, errors, cycle_count;

    // Instancia del DUT (Device Under Test)
    SystolicArray8x8 #(
        .DATA_WIDTH(16),
        .ACC_WIDTH (32)
    ) dut (
        .clk   (clk),
        .rst_n (rst_n),
        .A_in  (A_in_tb),
        .B_in  (B_in_tb),
        .C_out (C_out_tb)
    );

    // ----------------------------
    // Generador de reloj (10 ns)
    // ----------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ----------------------------
    // Inicialización y reset
    // ----------------------------
    initial begin
        // Inicializa las matrices:
        // A_matrix[i][j] = i*8 + j + 1   → 1,2,3,...,64
        // B_matrix[i][j] = 64 - (i*8 + j) → 64,63,...,1
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                A_matrix[i][j] = i*8 + j + 1;
                B_matrix[i][j] = 64 - (i*8 + j);
            end
        end

        // Fuerza las entradas a cero hasta salir del reset
        for (i = 0; i < 8; i = i + 1) begin
            A_in_tb[i] = 0;
            B_in_tb[i] = 0;
        end

        // Reset activo-bajo por dos ciclos
        rst_n = 0;
        repeat (2) @(posedge clk);
        rst_n = 1;
        
        $display("Iniciando simulación del arreglo sistólico 8x8...");
        $display("Matriz A:");
        for (i = 0; i < 8; i = i + 1) begin
            $write("Fila %0d: ", i);
            for (j = 0; j < 8; j = j + 1) begin
                $write("%3d ", A_matrix[i][j]);
            end
            $display("");
        end
        
        $display("Matriz B:");
        for (i = 0; i < 8; i = i + 1) begin
            $write("Fila %0d: ", i);
            for (j = 0; j < 8; j = j + 1) begin
                $write("%3d ", B_matrix[i][j]);
            end
            $display("");
        end
    end

    // ---------------------------------------------------
    // Secuencia de estimulación: patrón sistólico correcto
    // ---------------------------------------------------
    initial begin
        cycle_count = 0;
        
        // Espera a que reset_n se deseleccione
        @(posedge rst_n);
        @(posedge clk);

        // Para un arreglo sistólico de 8x8, necesitamos 15 ciclos para procesar completamente
        // Ciclos 0-14: inyección escalonada de datos
        for (t = 0; t < 15; t = t + 1) begin
            // Inicializar entradas en cero
            for (i = 0; i < 8; i = i + 1) begin
                A_in_tb[i] = 0;
                B_in_tb[i] = 0;
            end
            
            // Inyectar datos de A (escalonado por filas)
            for (i = 0; i < 8; i = i + 1) begin
                k = t - i;  // índice de columna ajustado por el escalonamiento
                if (k >= 0 && k < 8) begin
                    A_in_tb[i] = A_matrix[i][k];
                end
            end
            
            // Inyectar datos de B (escalonado por columnas)  
            for (j = 0; j < 8; j = j + 1) begin
                k = t - j;  // índice de fila ajustado por el escalonamiento
                if (k >= 0 && k < 8) begin
                    B_in_tb[j] = B_matrix[k][j];
                end
            end
            
            $display("Ciclo %2d: A_in = [%3d,%3d,%3d,%3d,%3d,%3d,%3d,%3d], B_in = [%3d,%3d,%3d,%3d,%3d,%3d,%3d,%3d]", 
                     t, A_in_tb[0], A_in_tb[1], A_in_tb[2], A_in_tb[3], A_in_tb[4], A_in_tb[5], A_in_tb[6], A_in_tb[7],
                        B_in_tb[0], B_in_tb[1], B_in_tb[2], B_in_tb[3], B_in_tb[4], B_in_tb[5], B_in_tb[6], B_in_tb[7]);
            
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        // Ciclos adicionales para drenar completamente la pipeline
        // Necesitamos más ciclos para que los PEs en las esquinas inferiores derechas terminen
        for (t = 15; t < 25; t = t + 1) begin
            for (i = 0; i < 8; i = i + 1) begin
                A_in_tb[i] = 0;
                B_in_tb[i] = 0;
            end
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        // Esperar ciclos adicionales para que se estabilicen las salidas
        repeat(5) @(posedge clk);

        // Mostrar resultados
        $display("\nMatriz C resultante (A*B) después de %0d ciclos:", cycle_count);
        for (i = 0; i < 8; i = i + 1) begin
            $write("Fila %0d: ", i);
            for (j = 0; j < 8; j = j + 1) begin
                $write("%6d ", C_out_tb[i][j]);
            end
            $display("");
        end

        // Genera referencia de software y compara
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                C_ref[i][j] = 0;
                for (k = 0; k < 8; k = k + 1) begin
                    C_ref[i][j] += A_matrix[i][k] * B_matrix[k][j];
                end
            end
        end

        $display("\nMatriz C_ref (referencia):");
        for (i = 0; i < 8; i = i + 1) begin
            $write("Fila %0d: ", i);
            for (j = 0; j < 8; j = j + 1) begin
                $write("%6d ", C_ref[i][j]);
            end
            $display("");
        end

        errors = 0;
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                if (C_out_tb[i][j] !== C_ref[i][j]) begin
                    $display("ERROR en C[%0d][%0d]: got %0d, expected %0d",
                             i, j, C_out_tb[i][j], C_ref[i][j]);
                    errors = errors + 1;
                end
            end
        end

        if (errors == 0)
            $display("\n=== TEST PASADO: Todos los elementos coinciden. ===");
        else
            $display("\n=== TEST FALLIDO: %0d errores encontrados. ===", errors);

        $finish;
    end

endmodule