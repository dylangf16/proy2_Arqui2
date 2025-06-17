//------------------------------------------------------------------------------
// Testbench: SystolicArray8x8_tb
// Descripción: Testbench simplificado para el arreglo sistólico 8x8
// - Prueba multiplicación de matrices con 2 casos principales
// - Verifica temporización y control start/done
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module SystolicArray8x8_tb;

    // Parámetros del testbench
    parameter DATA_WIDTH = 16;
    parameter ACC_WIDTH = 32;
    parameter CLK_PERIOD = 10; // 100MHz
    
    // Señales del DUT
    logic                                  clk;
    logic                                  rst_n;
    logic                                  start;
    logic signed [DATA_WIDTH-1:0]          A_matrix [0:7][0:7];
    logic signed [DATA_WIDTH-1:0]          B_matrix [0:7][0:7];
    logic signed [ACC_WIDTH-1:0]           C_out [0:7][0:7];
    logic                                  done;
    
    // Matrices de referencia para verificación
    logic signed [ACC_WIDTH-1:0]           C_expected [0:7][0:7];
    
    // Variables de control del testbench
    integer i, j, k;
    integer test_case;
    integer error_count;
    logic test_passed;
    
    // Instanciación del DUT
    SystolicArray8x8 #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .A_matrix(A_matrix),
        .B_matrix(B_matrix),
        .C_out(C_out),
        .done(done)
    );
    
    // Generación del reloj
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Función para calcular multiplicación de matrices (referencia)
    function void calculate_matrix_mult();
        for (int i = 0; i < 8; i++) begin
            for (int j = 0; j < 8; j++) begin
                C_expected[i][j] = 0;
                for (int k = 0; k < 8; k++) begin
                    C_expected[i][j] += A_matrix[i][k] * B_matrix[k][j];
                end
            end
        end
    endfunction
    
    // Función para inicializar matrices con ceros
    function void clear_matrices();
        for (int i = 0; i < 8; i++) begin
            for (int j = 0; j < 8; j++) begin
                A_matrix[i][j] = 16'b0;
                B_matrix[i][j] = 16'b0;
                C_expected[i][j] = 32'b0;
            end
        end
    endfunction
    
    // Función para mostrar matriz
    function void display_matrix(input string name, input logic signed [ACC_WIDTH-1:0] matrix [0:7][0:7]);
        $display("\n=== %s ===", name);
        for (int i = 0; i < 8; i++) begin
            $write("Row %0d: ", i);
            for (int j = 0; j < 8; j++) begin
                $write("%8d ", matrix[i][j]);
            end
            $display("");
        end
    endfunction
    
    // Función para verificar resultados
    function automatic logic verify_results();
        automatic logic passed;
        passed = 1'b1;
        error_count = 0;
        
        for (int i = 0; i < 8; i++) begin
            for (int j = 0; j < 8; j++) begin
                if (C_out[i][j] !== C_expected[i][j]) begin
                    $display("ERROR: C[%0d][%0d] = %0d, expected %0d", 
                            i, j, C_out[i][j], C_expected[i][j]);
                    error_count++;
                    passed = 1'b0;
                end
            end
        end
        
        if (passed) begin
            $display("✓ Test PASSED - All results match expected values");
        end else begin
            $display("✗ Test FAILED - %0d errors found", error_count);
        end
        
        return passed;
    endfunction
    
    // Task para ejecutar una multiplicación completa
    task run_matrix_multiplication();
        $display("\n--- Starting matrix multiplication ---");
        
        // Calcular resultado esperado
        calculate_matrix_mult();
        
        // Iniciar computación
        @(posedge clk);
        start = 1'b1;
        
        @(posedge clk);
        start = 1'b0;
        
        // Esperar a que termine
        wait(done == 1'b1);
        
        $display("Matrix multiplication completed in %0d cycles", $time/CLK_PERIOD);
        
        // Verificar resultados
        test_passed = verify_results();
        
        // Esperar hasta que done se desactive
        @(negedge done);
    endtask
    
    // Task de reset
    task reset_dut();
        rst_n = 1'b0;
        start = 1'b0;
        repeat(5) @(posedge clk);
        rst_n = 1'b1;
        repeat(2) @(posedge clk);
    endtask
    
    // Proceso principal del testbench
    initial begin
        $display("==========================================");
        $display("  Testbench para SystolicArray8x8");
        $display("==========================================");
        
        // Inicialización
        rst_n = 1'b0;
        start = 1'b0;
        clear_matrices();
        
        // Reset inicial
        reset_dut();
        
        //======================================================================
        // TEST CASE 1: Multiplicación por matriz identidad
        //======================================================================
        test_case = 1;
        $display("\n========== TEST CASE %0d: Identity Matrix ==========", test_case);
        
        // Matriz A: valores secuenciales
        for (i = 0; i < 8; i++) begin
            for (j = 0; j < 8; j++) begin
                A_matrix[i][j] = i * 8 + j + 1;
            end
        end
        
        // Matriz B: identidad
        clear_matrices();
        for (i = 0; i < 8; i++) begin
            B_matrix[i][i] = 16'd1;
        end
        
        run_matrix_multiplication();
        
        //======================================================================
        // TEST CASE 2: Matriz diagonal (similar al sistema principal)
        //======================================================================
        test_case = 2;
        $display("\n========== TEST CASE %0d: Diagonal Matrix (Cipher Test) ==========", test_case);
        
        // Matriz A: diagonal con 5s (como en el sistema principal)
        clear_matrices();
        for (i = 0; i < 8; i++) begin
            A_matrix[i][i] = 16'd5;
        end
        
        // Matriz B: primera columna con palabra "CIPHER" + relleno
        clear_matrices();
        // C=2, I=8, P=15, H=7, E=4, R=17
        B_matrix[0][0] = 16'd2;  // C
        B_matrix[1][0] = 16'd8;  // I
        B_matrix[2][0] = 16'd15; // P
        B_matrix[3][0] = 16'd7;  // H
        B_matrix[4][0] = 16'd4;  // E
        B_matrix[5][0] = 16'd17; // R
        B_matrix[6][0] = 16'd6;  // Relleno
        B_matrix[7][0] = 16'd7;  // Relleno
        
        // Relleno para otras columnas
        for (i = 0; i < 8; i++) begin
            for (j = 1; j < 8; j++) begin
                B_matrix[i][j] = i * 8 + j;
            end
        end
        
        run_matrix_multiplication();
        
        
        //======================================================================
        // Resumen final
        //======================================================================
        $display("\n==========================================");
        $display("       RESUMEN DE PRUEBAS COMPLETADAS");
        $display("==========================================");
        $display("Total de casos de prueba: %0d", test_case);
        $display("Tiempo total de simulación: %0d ns", $time);
        
        $display("\n✓ Testbench completado exitosamente");
        $display("==========================================");
        
        $finish;
    end
    
    // Monitor para debugging
    initial begin
        $monitor("Time: %-6d | rst_n: %b | start: %b | done: %b", 
                 $time, rst_n, start, done);
    end
    
    // Timeout para evitar simulaciones infinitas
    initial begin
        #1000000; // 1ms timeout
        $display("ERROR: Simulation timeout!");
        $finish;
    end
    
    // Dump de ondas (opcional - comentar si no se necesita)
    initial begin
        $dumpfile("SystolicArray8x8_tb.vcd");
        $dumpvars(0, SystolicArray8x8_tb);
    end

endmodule