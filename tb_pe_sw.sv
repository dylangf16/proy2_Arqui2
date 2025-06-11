//------------------------------------------------------------------------------
// Testbench Unitario: tb_pe_sw.sv
// Propósito: Pruebas unitarias del elemento de procesamiento PE_SW
// Validación: Multiplicación, acumulación y propagación de datos
//------------------------------------------------------------------------------

module tb_pe_sw;

    // Parámetros del testbench
    parameter DATA_WIDTH = 16;
    parameter ACC_WIDTH  = 32;
    parameter CLK_PERIOD = 10; // 100MHz

    // Señales del testbench
    logic                            clk;
    logic                            rst_n;
    logic signed [DATA_WIDTH-1:0]    A_in;
    logic signed [DATA_WIDTH-1:0]    B_in;
    logic signed [ACC_WIDTH-1:0]     psum_in;
    logic signed [DATA_WIDTH-1:0]    A_out;
    logic signed [DATA_WIDTH-1:0]    B_out;
    logic signed [ACC_WIDTH-1:0]     psum_out;

    // Variables de control del testbench
    integer test_case;
    integer errors;
    logic signed [ACC_WIDTH-1:0] expected_psum;

    // Instancia del DUT (Device Under Test)
    PE_SW #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .A_in(A_in),
        .B_in(B_in),
        .psum_in(psum_in),
        .A_out(A_out),
        .B_out(B_out),
        .psum_out(psum_out)
    );

    // Generador de reloj
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Proceso principal de pruebas
    initial begin
        $display("=== INICIANDO PRUEBAS UNITARIAS PE_SW ===");
        $display("Parámetros: DATA_WIDTH=%0d, ACC_WIDTH=%0d", DATA_WIDTH, ACC_WIDTH);
        
        errors = 0;
        test_case = 0;
        
        // Inicialización
        A_in = 0;
        B_in = 0;
        psum_in = 0;
        
        // Test 1: Verificación de Reset
        test_case = 1;
        $display("\nTest %0d: Verificación de Reset", test_case);
        rst_n = 0;
        repeat(3) @(posedge clk);
        
        if (A_out !== 0 || B_out !== 0 || psum_out !== 0) begin
            $display("ERROR: Reset no funcionó correctamente");
            $display("  A_out=%0d, B_out=%0d, psum_out=%0d", A_out, B_out, psum_out);
            errors++;
        end else begin
            $display("PASS: Reset funcionó correctamente");
        end
        
        rst_n = 1;
        @(posedge clk);

        // Test 2: Propagación básica sin acumulación (datos = 0)
        test_case = 2;
        $display("\nTest %0d: Propagación con datos cero", test_case);
        A_in = 0;
        B_in = 0;
        @(posedge clk);
        @(posedge clk); // Esperar propagación
        
        if (A_out !== 0 || B_out !== 0 || psum_out !== 0) begin
            $display("ERROR: Propagación con ceros falló");
            $display("  A_out=%0d, B_out=%0d, psum_out=%0d", A_out, B_out, psum_out);
            errors++;
        end else begin
            $display("PASS: Propagación con ceros correcta");
        end

        // Test 3: Primera multiplicación y acumulación
        test_case = 3;
        $display("\nTest %0d: Primera multiplicación (3 × 4 = 12)", test_case);
        A_in = 3;
        B_in = 4;
        expected_psum = 12;
        @(posedge clk);
        @(posedge clk); // Esperar un ciclo para que se propague
        
        if (A_out !== 3 || B_out !== 4) begin
            $display("ERROR: Propagación de datos incorrecta");
            $display("  A_out=%0d (expected 3), B_out=%0d (expected 4)", A_out, B_out);
            errors++;
        end else if (psum_out !== expected_psum) begin
            $display("ERROR: Acumulación incorrecta");
            $display("  psum_out=%0d (expected %0d)", psum_out, expected_psum);
            errors++;
        end else begin
            $display("PASS: Primera multiplicación correcta");
        end

        // Test 4: Segunda multiplicación y acumulación
        test_case = 4;
        $display("\nTest %0d: Segunda multiplicación (5 × 6 = 30, total = 42)", test_case);
        A_in = 5;
        B_in = 6;
        expected_psum = 12 + 30; // Acumulación
        @(posedge clk);
        @(posedge clk);
        
        if (A_out !== 5 || B_out !== 6) begin
            $display("ERROR: Propagación de datos incorrecta");
            $display("  A_out=%0d (expected 5), B_out=%0d (expected 6)", A_out, B_out);
            errors++;
        end else if (psum_out !== expected_psum) begin
            $display("ERROR: Acumulación incorrecta");
            $display("  psum_out=%0d (expected %0d)", psum_out, expected_psum);
            errors++;
        end else begin
            $display("PASS: Segunda multiplicación y acumulación correcta");
        end

        // Test 5: Multiplicación con valores negativos
        test_case = 5;
        $display("\nTest %0d: Multiplicación con negativos (-2 × 7 = -14, total = 28)", test_case);
        A_in = -2;
        B_in = 7;
        expected_psum = 42 + (-14);
        @(posedge clk);
        @(posedge clk);
        
        if (psum_out !== expected_psum) begin
            $display("ERROR: Multiplicación con negativos incorrecta");
            $display("  psum_out=%0d (expected %0d)", psum_out, expected_psum);
            errors++;
        end else begin
            $display("PASS: Multiplicación con negativos correcta");
        end

        // Test 6: No acumulación cuando uno de los datos es cero
        test_case = 6;
        $display("\nTest %0d: No acumulación con A=0 (0 × 10, total = 28)", test_case);
        A_in = 0;
        B_in = 10;
        expected_psum = 28; // No debe cambiar
        @(posedge clk);
        @(posedge clk);
        
        if (psum_out !== expected_psum) begin
            $display("ERROR: Acumulación incorrecta con A=0");
            $display("  psum_out=%0d (expected %0d)", psum_out, expected_psum);
            errors++;
        end else begin
            $display("PASS: No acumulación con A=0 correcta");
        end

        // Test 7: No acumulación cuando B es cero
        test_case = 7;
        $display("\nTest %0d: No acumulación con B=0 (8 × 0, total = 28)", test_case);
        A_in = 8;
        B_in = 0;
        expected_psum = 28; // No debe cambiar
        @(posedge clk);
        @(posedge clk);
        
        if (psum_out !== expected_psum) begin
            $display("ERROR: Acumulación incorrecta con B=0");
            $display("  psum_out=%0d (expected %0d)", psum_out, expected_psum);
            errors++;
        end else begin
            $display("PASS: No acumulación con B=0 correcta");
        end

        // Test 8: Valores máximos
        test_case = 8;
        $display("\nTest %0d: Valores máximos (32767 × 1)", test_case);
        A_in = 32767; // Máximo valor de 16-bit signed
        B_in = 1;
        expected_psum = 28 + 32767;
        @(posedge clk);
        @(posedge clk);
        
        if (psum_out !== expected_psum) begin
            $display("ERROR: Multiplicación con valores máximos incorrecta");
            $display("  psum_out=%0d (expected %0d)", psum_out, expected_psum);
            errors++;
        end else begin
            $display("PASS: Multiplicación con valores máximos correcta");
        end

        // Test 9: Valores mínimos
        test_case = 9;
        $display("\nTest %0d: Valores mínimos (-32768 × 1)", test_case);
        A_in = -32768; // Mínimo valor de 16-bit signed
        B_in = 1;
        expected_psum = 28 + 32767 + (-32768);
        @(posedge clk);
        @(posedge clk);
        
        if (psum_out !== expected_psum) begin
            $display("ERROR: Multiplicación con valores mínimos incorrecta");
            $display("  psum_out=%0d (expected %0d)", psum_out, expected_psum);
            errors++;
        end else begin
            $display("PASS: Multiplicación con valores mínimos correcta");
        end

        // Test 10: Reset durante operación
        test_case = 10;
        $display("\nTest %0d: Reset durante operación", test_case);
        A_in = 100;
        B_in = 200;
        @(posedge clk);
        rst_n = 0; // Reset en medio de operación
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        if (A_out !== 0 || B_out !== 0 || psum_out !== 0) begin
            $display("ERROR: Reset durante operación no funcionó");
            $display("  A_out=%0d, B_out=%0d, psum_out=%0d", A_out, B_out, psum_out);
            errors++;
        end else begin
            $display("PASS: Reset durante operación funcionó correctamente");
        end

        // Resumen final
        $display("\n=== RESUMEN DE PRUEBAS UNITARIAS PE_SW ===");
        $display("Total de casos de prueba: %0d", test_case);
        $display("Errores encontrados: %0d", errors);
        
        if (errors == 0) begin
            $display("=== PRUEBAS UNITARIAS PASARON ===");
            $display("El PE_SW funciona correctamente en todos los casos");
        end else begin
            $display("=== PRUEBAS UNITARIAS FALLARON ===");
            $display("Se encontraron %0d errores en el PE_SW", errors);
        end
        
        $display("Simulación completada.");
        $finish;
    end

    // Monitor para debugging (opcional)
    initial begin
        $monitor("Tiempo=%0t: A_in=%0d, B_in=%0d, A_out=%0d, B_out=%0d, psum_out=%0d", 
                 $time, A_in, B_in, A_out, B_out, psum_out);
    end

endmodule