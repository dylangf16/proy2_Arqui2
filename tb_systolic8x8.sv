`timescale 1ns/1ps

//------------------------------------------------------------------------------
// Testbench completo: tb_systolic8x8.sv
// Con debug de propagación interna (A_bus_out, B_bus_out y pre_act)
//------------------------------------------------------------------------------

module tb_systolic8x8;

    // Reloj y reset
    logic clk;
    logic rst_n;

    // Entradas al arreglo
    logic signed [15:0] A_in_tb   [0:7];
    logic signed [15:0] B_in_tb   [0:7];

    // Salidas del arreglo (antes y después de activación)
    logic signed [31:0] pre_act_tb[0:7][0:7];
    logic signed [31:0] C_out_tb  [0:7][0:7];

    // Matrices de referencia
    logic signed [15:0] A_matrix [0:7][0:7];
    logic signed [15:0] B_matrix [0:7][0:7];
    logic signed [31:0] C_ref    [0:7][0:7];

    // Variables de control
    integer i, j, t, k, errors;
    integer cycle_count;

    // Instancia del DUT
    SystolicArray8x8 #(
        .DATA_WIDTH(16),
        .ACC_WIDTH (32)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .A_in    (A_in_tb),
        .B_in    (B_in_tb),
        .pre_act (pre_act_tb),
        .C_out   (C_out_tb)
    );

    // ---------------------------------------------------
    // Generador de reloj: periodo = 10 ns (50 MHz)
    // ---------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ---------------------------------------------------
    // Inicialización de matrices y reset
    // ---------------------------------------------------
    initial begin
        // Carga de matrices A y B
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                A_matrix[i][j] = i*8 + j + 1;       // 1…64
                B_matrix[i][j] = 64 - (i*8 + j);    // 64…1
            end
            // Entradas limpias hasta desactivar reset
            A_in_tb[i] = 0;
            B_in_tb[i] = 0;
        end

        // Aplicar reset (activo bajo) durante 2 ciclos de reloj
        rst_n = 0;
        repeat (2) @(posedge clk);
        rst_n = 1;

        $display("=== Simulación iniciada ===");
    end

    // ---------------------------------------------------
    // Debug: imprime A_bus_out, B_bus_out y pre_act
    // ---------------------------------------------------
    always @(posedge clk) begin
        if (rst_n) begin
            cycle_count = cycle_count + 1;

            // Solo durante los primeros 10 ciclos para no saturar consola
            if (cycle_count < 15) begin
                $display("\n--- Ciclo %0d ---", cycle_count);

                // Propagación horizontal (A_bus_out)
                for (integer ii = 0; ii < 8; ii = ii + 1) begin
                    $write("A_bus row%0d: ", ii);
                    for (integer jj = 0; jj < 8; jj = jj + 1)
                        $write("%4d ", dut.A_bus_out[ii][jj]);
                    $display("");
                end

                // Propagación vertical (B_bus_out)
                for (integer jj = 0; jj < 8; jj = jj + 1) begin
                    $write("B_bus col%0d: ", jj);
                    for (integer ii = 0; ii < 8; ii = ii + 1)
                        $write("%4d ", dut.B_bus_out[ii][jj]);
                    $display("");
                end

                // Acumulado antes de ReLU (pre_act)
                for (integer ii = 0; ii < 8; ii = ii + 1) begin
                    $write("pre_act[%0d]: ", ii);
                    for (integer jj = 0; jj < 8; jj = jj + 1)
                        $write("%6d ", pre_act_tb[ii][jj]);
                    $display("");
                end
            end
        end
    end

    // ---------------------------------------------------
    // Secuencia de inyección y verificación completa
    // ---------------------------------------------------
    initial begin
        // Para que el primer flanco tras rst_n sea ciclo 0
        cycle_count = -1;

        // Esperar fin de reset
        @(posedge rst_n);
        @(posedge clk);

        // Ciclos 0–14: inyección escalonada de datos
        for (t = 0; t < 15; t = t + 1) begin
            // Limpiar entradas
            for (i = 0; i < 8; i = i + 1) begin
                A_in_tb[i] = 0;
                B_in_tb[i] = 0;
            end
            // Inyectar A por filas escalonadas
            for (i = 0; i < 8; i = i + 1) begin
                k = t - i;
                if (k >= 0 && k < 8)
                    A_in_tb[i] = A_matrix[i][k];
            end
            // Inyectar B por columnas escalonadas
            for (j = 0; j < 8; j = j + 1) begin
                k = t - j;
                if (k >= 0 && k < 8)
                    B_in_tb[j] = B_matrix[k][j];
            end
            @(posedge clk);
        end

        // Ciclos 15–24: drenar pipeline
        for (t = 15; t < 25; t = t + 1) begin
            for (i = 0; i < 8; i = i + 1) begin
                A_in_tb[i] = 0;
                B_in_tb[i] = 0;
            end
            @(posedge clk);
        end

        // Esperar unos ciclos para estabilizar salidas
        repeat (5) @(posedge clk);

        // Calcular referencia en software
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                C_ref[i][j] = 0;
                for (k = 0; k < 8; k = k + 1)
                    C_ref[i][j] += A_matrix[i][k] * B_matrix[k][j];
            end
        end

        // Comparar
        errors = 0;
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                if (C_out_tb[i][j] !== C_ref[i][j]) begin
                    $display("ERROR en C[%0d][%0d]: got %0d, exp %0d",
                             i, j, C_out_tb[i][j], C_ref[i][j]);
                    errors = errors + 1;
                end
            end
        end

        if (errors == 0)
            $display("\n=== TEST PASADO en %0d ciclos ===", cycle_count);
        else
            $display("\n=== TEST FALLIDO: %0d errores ===", errors);

        $finish;
    end

endmodule
