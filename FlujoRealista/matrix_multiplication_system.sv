//------------------------------------------------------------------------------
// Module: matrix_multiplication_system
// Descripción: Sistema completo con cifrado por matriz - Matriz diagonal 5s x Palabra
// Aplica módulo 26 al resultado final
//------------------------------------------------------------------------------

module matrix_multiplication_system (
    input  logic           clk_clk,
    input  logic           reset_reset_n,
    input  logic           btn2,
    
    // Pines físicos hacia la SDRAM
    output logic [12:0]    wire_addr,
    output logic [1:0]     wire_ba,
    output logic           wire_cas_n,
    output logic           wire_cke,
    output logic           wire_cs_n,
    inout  logic [15:0]    wire_dq,
    output logic [1:0]     wire_dqm,
    output logic           wire_ras_n,
    output logic           wire_we_n,
    
    // Display de 7 segmentos - AHORA 6 displays
    output logic [6:0]     hex0,
    output logic [6:0]     hex1,
    output logic [6:0]     hex2,
    output logic [6:0]     hex3,
    output logic [6:0]     hex4,
    output logic [6:0]     hex5
);

    // Parámetros del sistema
    parameter DATA_WIDTH = 16;
    parameter ACC_WIDTH = 32;
    
    // Direcciones base en SDRAM
    parameter [24:0] MATRIX_A_BASE = 25'h000000;
    parameter [24:0] MATRIX_B_BASE = 25'h000400;
    parameter [24:0] MATRIX_C_BASE = 25'h000800;
    
    // Palabra a codificar (6 caracteres): "CIPHER"
    // C=2, I=8, P=15, H=7, E=4, R=17
    // Fixed: Explicitly declare the parameter type for array
    parameter logic [7:0] WORD_CHARS [0:5] = '{8'd2, 8'd8, 8'd15, 8'd7, 8'd4, 8'd17};
    
    // Señales del controlador SDRAM
    logic [24:0] sdram_address;
    logic [1:0]  sdram_byteenable_n;
    logic        sdram_chipselect;
    logic [15:0] sdram_writedata;
    logic        sdram_read_n;
    logic        sdram_write_n;
    logic [15:0] sdram_readdata;
    logic        sdram_readdatavalid;
    logic        sdram_waitrequest;
    
    // Señales de la interfaz SDRAM
    logic        start_write;
    logic        start_read;
    logic [24:0] address;
    logic [15:0] write_data;
    logic [15:0] read_data;
    logic        operation_done;
    logic        busy;
    
    // Señales del arreglo sistólico
    logic signed [DATA_WIDTH-1:0] matrix_a_internal [0:7][0:7];
    logic signed [DATA_WIDTH-1:0] matrix_b_internal [0:7][0:7];
    logic signed [ACC_WIDTH-1:0]  C_out [0:7][0:7];
    logic        systolic_start;
    logic        systolic_done;
    logic        computing_active;
    
    // Estados principales
    typedef enum logic [4:0] {
        INIT,
        STORE_MATRIX_A,
        STORE_MATRIX_B,
        LOAD_MATRIX_A,
        LOAD_MATRIX_B,
        SYSTOLIC_COMPUTE,
        STORE_RESULTS,
        LOAD_RESULTS,
        DISPLAY_RESULTS,
        IDLE
    } main_state_t;
    
    main_state_t current_state, next_state;
    
    // Performance counters
    logic [63:0] cycle_counter;
    logic [31:0] arithmetic_ops_counter;
    logic [31:0] memory_accesses_counter;
    logic [31:0] compute_cycles;
    
    // Contadores auxiliares
    logic [6:0]  matrix_index;
    logic [6:0]  result_index;
    logic [3:0]  display_mode;
    
    // Matrices generadas y cargadas
    logic signed [15:0] matrix_a_generated [0:7][0:7]; // Matriz diagonal con 5s
    logic signed [15:0] matrix_b_generated [0:7][0:7]; // Matriz con palabra
    logic signed [15:0] matrix_a_loaded [0:7][0:7];
    logic signed [15:0] matrix_b_loaded [0:7][0:7];
    logic signed [31:0] results_loaded [0:7][0:7];
    logic [7:0] cipher_result [0:5]; // Resultado cifrado (primera columna, mod 26)
    logic [7:0] original_word [0:5]; // Palabra original
    
    // Control del display
    logic        btn2_prev, btn2_edge;
    logic [47:0] display_word; // 6 caracteres de 8 bits cada uno
    logic [31:0] arithmetic_intensity_x100;
    
    // Delay de inicialización
    logic [25:0] init_delay_counter;
    logic        init_delay_done;
    
    // Detección de operaciones de memoria válidas
    logic        memory_op_valid;
    logic        memory_op_prev;
    logic        memory_op_pulse;
    
    // Señales de debug
    logic [3:0] state_debug;
    
    // Control mejorado de timing
    logic [7:0] state_timer;
    logic state_timeout;
    
    // Flags de validación de datos
    logic matrix_a_valid;
    logic matrix_b_valid;
    logic results_valid;
    logic systolic_data_loaded;
    
    // Instanciación del controlador SDRAM
    sdram sdram_controller (
        .clk_clk(clk_clk),
        .reset_reset_n(reset_reset_n),
        .sdram_address(sdram_address),
        .sdram_byteenable_n(sdram_byteenable_n),
        .sdram_chipselect(sdram_chipselect),
        .sdram_writedata(sdram_writedata),
        .sdram_read_n(sdram_read_n),
        .sdram_write_n(sdram_write_n),
        .sdram_readdata(sdram_readdata),
        .sdram_readdatavalid(sdram_readdatavalid),
        .sdram_waitrequest(sdram_waitrequest),
        .wire_addr(wire_addr),
        .wire_ba(wire_ba),
        .wire_cas_n(wire_cas_n),
        .wire_cke(wire_cke),
        .wire_cs_n(wire_cs_n),
        .wire_dq(wire_dq),
        .wire_dqm(wire_dqm),
        .wire_ras_n(wire_ras_n),
        .wire_we_n(wire_we_n)
    );
    
    // Instanciación de la interfaz SDRAM
    sdram_interface sdram_if (
        .clk(clk_clk),
        .reset_n(reset_reset_n),
        .start_write(start_write),
        .start_read(start_read),
        .address(address),
        .write_data(write_data),
        .read_data(read_data),
        .operation_done(operation_done),
        .busy(busy),
        .sdram_address(sdram_address),
        .sdram_byteenable_n(sdram_byteenable_n),
        .sdram_chipselect(sdram_chipselect),
        .sdram_writedata(sdram_writedata),
        .sdram_read_n(sdram_read_n),
        .sdram_write_n(sdram_write_n),
        .sdram_readdata(sdram_readdata),
        .sdram_readdatavalid(sdram_readdatavalid),
        .sdram_waitrequest(sdram_waitrequest)
    );
    
    // Instanciación del arreglo sistólico
    SystolicArray8x8 #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) systolic_array (
        .clk(clk_clk),
        .rst_n(reset_reset_n),
        .start(systolic_start),
        .A_matrix(matrix_a_internal),
        .B_matrix(matrix_b_internal),
        .C_out(C_out),
        .done(systolic_done)
    );
    
    // Timer de estado para debugging
    always_ff @(posedge clk_clk or negedge reset_reset_n) begin
        if (!reset_reset_n) begin
            state_timer <= 8'b0;
            state_timeout <= 1'b0;
        end else begin
            if (current_state != next_state) begin
                state_timer <= 8'b0;
                state_timeout <= 1'b0;
            end else if (state_timer < 8'd200) begin
                state_timer <= state_timer + 1;
            end else begin
                state_timeout <= 1'b1;
            end
        end
    end
    
    // Debug del estado actual
    always_comb begin
        case (current_state)
            INIT: state_debug = 4'h0;
            STORE_MATRIX_A: state_debug = 4'h1;
            STORE_MATRIX_B: state_debug = 4'h2;
            LOAD_MATRIX_A: state_debug = 4'h3;
            LOAD_MATRIX_B: state_debug = 4'h4;
            SYSTOLIC_COMPUTE: state_debug = 4'h5;
            STORE_RESULTS: state_debug = 4'h6;
            LOAD_RESULTS: state_debug = 4'h7;
            DISPLAY_RESULTS: state_debug = 4'h8;
            default: state_debug = 4'hF;
        endcase
    end
    
    // Contador de delay para inicialización
    always_ff @(posedge clk_clk or negedge reset_reset_n) begin
        if (!reset_reset_n) begin
            init_delay_counter <= 26'b0;
            init_delay_done <= 1'b0;
        end else begin
            if (init_delay_counter < 26'd100) begin
                init_delay_counter <= init_delay_counter + 1;
            end else begin
                init_delay_done <= 1'b1;
            end
        end
    end
    
    // Generación de matrices
    always_ff @(posedge clk_clk or negedge reset_reset_n) begin
        if (!reset_reset_n) begin
            // Matriz A: diagonal con 5s
            for (int i = 0; i < 8; i++) begin
                for (int j = 0; j < 8; j++) begin
                    if (i == j) begin
                        matrix_a_generated[i][j] <= 16'd5;
                    end else begin
                        matrix_a_generated[i][j] <= 16'd0;
                    end
                end
            end
            
            // Matriz B: primera columna es la palabra "CIPHER", resto rellenado
            for (int i = 0; i < 8; i++) begin
                for (int j = 0; j < 8; j++) begin
                    if (j == 0) begin // Primera columna - palabra
                        if (i < 6) begin
                            matrix_b_generated[i][j] <= 16'(WORD_CHARS[i]);
                        end else begin
                            matrix_b_generated[i][j] <= 16'(i); // Relleno con números
                        end
                    end else begin // Otras columnas - relleno secuencial
                        matrix_b_generated[i][j] <= 16'(i * 8 + j);
                    end
                end
            end
            
            // Inicializar palabra original para display
            for (int i = 0; i < 6; i++) begin
                original_word[i] <= WORD_CHARS[i];
            end
        end
    end
    
    // Flags de validación
    always_ff @(posedge clk_clk or negedge reset_reset_n) begin
        if (!reset_reset_n) begin
            matrix_a_valid <= 1'b0;
            matrix_b_valid <= 1'b0;
            results_valid <= 1'b0;
            systolic_data_loaded <= 1'b0;
        end else begin
            case (current_state)
                LOAD_MATRIX_A: begin
                    if (operation_done && matrix_index == 63) begin
                        matrix_a_valid <= 1'b1;
                    end
                end
                
                LOAD_MATRIX_B: begin
                    if (operation_done && matrix_index == 63) begin
                        matrix_b_valid <= 1'b1;
                    end
                end
                
                SYSTOLIC_COMPUTE: begin
                    if (systolic_start && !systolic_data_loaded) begin
                        systolic_data_loaded <= 1'b1;
                    end else if (systolic_done) begin
                        results_valid <= 1'b1;
                    end
                end
                
                LOAD_RESULTS: begin
                    if (operation_done && result_index == 63) begin
                        results_valid <= 1'b1;
                    end
                end
                
                INIT: begin
                    matrix_a_valid <= 1'b0;
                    matrix_b_valid <= 1'b0;
                    results_valid <= 1'b0;
                    systolic_data_loaded <= 1'b0;
                end
            endcase
        end
    end
    
    // Control de computación activa
    always_ff @(posedge clk_clk or negedge reset_reset_n) begin
        if (!reset_reset_n) begin
            computing_active <= 1'b0;
        end else begin
            if (current_state == SYSTOLIC_COMPUTE && systolic_start && !computing_active) begin
                computing_active <= 1'b1;
            end else if (systolic_done) begin
                computing_active <= 1'b0;
            end
        end
    end
    
    // Detección de operaciones de memoria válidas
    always_ff @(posedge clk_clk or negedge reset_reset_n) begin
        if (!reset_reset_n) begin
            memory_op_prev <= 1'b0;
            memory_op_pulse <= 1'b0;
        end else begin
            memory_op_prev <= memory_op_valid;
            memory_op_pulse <= memory_op_valid && !memory_op_prev;
        end
    end
    
    always_comb begin
        memory_op_valid = (start_write || start_read) && !busy && 
                         (current_state == STORE_MATRIX_A || 
                          current_state == STORE_MATRIX_B || 
                          current_state == LOAD_MATRIX_A ||
                          current_state == LOAD_MATRIX_B ||
                          current_state == STORE_RESULTS ||
                          current_state == LOAD_RESULTS);
    end
    
    // Performance counters
    always_ff @(posedge clk_clk or negedge reset_reset_n) begin
			 if (!reset_reset_n) begin
				  cycle_counter <= 64'b0;
				  arithmetic_ops_counter <= 32'b0;
				  memory_accesses_counter <= 32'b0;
				  compute_cycles <= 32'b0;
			 end else begin
				  cycle_counter <= cycle_counter + 1;
				  
				  // Contar accesos a memoria cuando realmente ocurren
				  if (memory_op_pulse) begin
						memory_accesses_counter <= memory_accesses_counter + 1;
				  end
				  
				  // Contar ciclos de cómputo
				  if (computing_active) begin
						compute_cycles <= compute_cycles + 1;
				  end
				  
				  // Contar operaciones aritméticas más precisamente
				  if (systolic_start && !computing_active) begin
						// Una multiplicación de matrices 8x8 requiere 8³ = 512 operaciones
						arithmetic_ops_counter <= arithmetic_ops_counter + 32'd512;
				  end
			 end
		end
    
    // Cálculo de intensidad aritmética
    always_comb begin
        if (memory_accesses_counter > 0) begin
            arithmetic_intensity_x100 = (arithmetic_ops_counter * 100) / memory_accesses_counter;
        end else begin
            arithmetic_intensity_x100 = 32'b0;
        end
    end
    
    // Detección de flanco del botón
    always_ff @(posedge clk_clk or negedge reset_reset_n) begin
        if (!reset_reset_n) begin
            btn2_prev <= 1'b0;
            btn2_edge <= 1'b0;
        end else begin
            btn2_prev <= btn2;
            btn2_edge <= btn2 && !btn2_prev;
        end
    end
    
    // Control del display mode (0=palabra original, 1=palabra cifrada, 2=performance)
    always_ff @(posedge clk_clk or negedge reset_reset_n) begin
        if (!reset_reset_n) begin
            display_mode <= 4'b0;
        end else if (btn2_edge && current_state == DISPLAY_RESULTS) begin
            if (display_mode == 4'd5) begin
                display_mode <= 4'b0;
            end else begin
                display_mode <= display_mode + 1;
            end
        end
    end
    
    // Máquina de estados principal
    always_ff @(posedge clk_clk or negedge reset_reset_n) begin
        if (!reset_reset_n) begin
            current_state <= INIT;
            matrix_index <= 7'b0;
            result_index <= 7'b0;
        end else begin
            current_state <= next_state;
            
            case (current_state)
                STORE_MATRIX_A, STORE_MATRIX_B, LOAD_MATRIX_A, LOAD_MATRIX_B: begin
                    if (operation_done && matrix_index < 63) begin
                        matrix_index <= matrix_index + 1;
                    end else if (operation_done && matrix_index == 63) begin
                        matrix_index <= 7'b0;
                    end
                end
                
                STORE_RESULTS, LOAD_RESULTS: begin
                    if (operation_done && result_index < 63) begin
                        result_index <= result_index + 1;
                    end else if (operation_done && result_index == 63) begin
                        result_index <= 7'b0;
                    end
                end
            endcase
        end
    end
    
    // Lógica de transición de estados
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            INIT: begin
                if (init_delay_done) begin
                    next_state = STORE_MATRIX_A;
                end
            end
            
            STORE_MATRIX_A: begin
                if ((operation_done && matrix_index == 63) || state_timeout) begin
                    next_state = STORE_MATRIX_B;
                end
            end
            
            STORE_MATRIX_B: begin
                if ((operation_done && matrix_index == 63) || state_timeout) begin
                    next_state = LOAD_MATRIX_A;
                end
            end
            
            LOAD_MATRIX_A: begin
                if ((operation_done && matrix_index == 63) || state_timeout) begin
                    next_state = LOAD_MATRIX_B;
                end
            end
            
            LOAD_MATRIX_B: begin
                if ((operation_done && matrix_index == 63) || state_timeout) begin
                    next_state = SYSTOLIC_COMPUTE;
                end
            end
            
            SYSTOLIC_COMPUTE: begin
                if (systolic_done || state_timeout) begin
                    next_state = STORE_RESULTS;
                end
            end
            
            STORE_RESULTS: begin
                if ((operation_done && result_index == 63) || state_timeout) begin
                    next_state = LOAD_RESULTS;
                end
            end
            
            LOAD_RESULTS: begin
                if ((operation_done && result_index == 63) || state_timeout) begin
                    next_state = DISPLAY_RESULTS;
                end
            end
            
            DISPLAY_RESULTS: begin
                next_state = DISPLAY_RESULTS;
            end
            
            default: begin
                next_state = INIT;
            end
        endcase
    end
    
    // Control de operaciones de memoria
    logic [3:0] mem_delay;
    
    always_ff @(posedge clk_clk or negedge reset_reset_n) begin
        if (!reset_reset_n) begin
            mem_delay <= 4'b0;
        end else begin
            if ((current_state == STORE_MATRIX_A || current_state == STORE_MATRIX_B ||
                 current_state == LOAD_MATRIX_A || current_state == LOAD_MATRIX_B ||
                 current_state == STORE_RESULTS || current_state == LOAD_RESULTS) && 
                !busy && mem_delay < 4'd5) begin
                mem_delay <= mem_delay + 1;
            end else if (operation_done || busy) begin
                mem_delay <= 4'b0;
            end
        end
    end
    
    // Control de memoria
    always_comb begin
        start_write = 1'b0;
        start_read = 1'b0;
        address = 25'b0;
        write_data = 16'b0;
        
        case (current_state)
            STORE_MATRIX_A: begin
                if (!busy && mem_delay >= 4'd5) begin
                    start_write = 1'b1;
                    address = MATRIX_A_BASE + {18'b0, matrix_index};
                    write_data = matrix_a_generated[matrix_index[5:3]][matrix_index[2:0]];
                end
            end
            
            STORE_MATRIX_B: begin
                if (!busy && mem_delay >= 4'd5) begin
                    start_write = 1'b1;
                    address = MATRIX_B_BASE + {18'b0, matrix_index};
                    write_data = matrix_b_generated[matrix_index[5:3]][matrix_index[2:0]];
                end
            end
            
            LOAD_MATRIX_A: begin
                if (!busy && mem_delay >= 4'd5) begin
                    start_read = 1'b1;
                    address = MATRIX_A_BASE + {18'b0, matrix_index};
                end
            end
            
            LOAD_MATRIX_B: begin
                if (!busy && mem_delay >= 4'd5) begin
                    start_read = 1'b1;
                    address = MATRIX_B_BASE + {18'b0, matrix_index};
                end
            end
            
            STORE_RESULTS: begin
                if (!busy && mem_delay >= 4'd5) begin
                    start_write = 1'b1;
                    address = MATRIX_C_BASE + {18'b0, result_index};
                    // Aplicar módulo 26 al guardar
                    write_data = 16'(C_out[result_index[5:3]][result_index[2:0]][15:0] % 26);
                end
            end
            
            LOAD_RESULTS: begin
                if (!busy && mem_delay >= 4'd5) begin
                    start_read = 1'b1;
                    address = MATRIX_C_BASE + {18'b0, result_index};
                end
            end
        endcase
    end
    
    // Captura de datos leídos desde SDRAM
    always_ff @(posedge clk_clk or negedge reset_reset_n) begin
        if (!reset_reset_n) begin
            for (int i = 0; i < 8; i++) begin
                for (int j = 0; j < 8; j++) begin
                    matrix_a_loaded[i][j] <= 16'b0;
                    matrix_b_loaded[i][j] <= 16'b0;
                    results_loaded[i][j] <= 32'b0;
                end
            end
        end else if (operation_done) begin
            case (current_state)
                LOAD_MATRIX_A: begin
                    matrix_a_loaded[matrix_index[5:3]][matrix_index[2:0]] <= read_data;
                end
                
                LOAD_MATRIX_B: begin
                    matrix_b_loaded[matrix_index[5:3]][matrix_index[2:0]] <= read_data;
                end
                
                LOAD_RESULTS: begin
                    results_loaded[result_index[5:3]][result_index[2:0]] <= {16'b0, read_data};
                end
            endcase
        end
    end
    
    // Control del arreglo sistólico
    always_ff @(posedge clk_clk or negedge reset_reset_n) begin
        if (!reset_reset_n) begin
            systolic_start <= 1'b0;
            for (int i = 0; i < 8; i++) begin
                for (int j = 0; j < 8; j++) begin
                    matrix_a_internal[i][j] <= 16'b0;
                    matrix_b_internal[i][j] <= 16'b0;
                end
            end
        end else begin
            case (current_state)
                SYSTOLIC_COMPUTE: begin
                    if (!systolic_start && !systolic_done && !computing_active && !systolic_data_loaded) begin
                        for (int i = 0; i < 8; i++) begin
                            for (int j = 0; j < 8; j++) begin
                                if (matrix_a_valid && matrix_b_valid) begin
                                    matrix_a_internal[i][j] <= matrix_a_loaded[i][j];
                                    matrix_b_internal[i][j] <= matrix_b_loaded[i][j];
                                end else begin
                                    matrix_a_internal[i][j] <= matrix_a_generated[i][j];
                                    matrix_b_internal[i][j] <= matrix_b_generated[i][j];
                                end
                            end
                        end
                        systolic_start <= 1'b1;
                    end else if (computing_active || systolic_done) begin
                        systolic_start <= 1'b0;
                    end
                end
                
                default: begin
                    systolic_start <= 1'b0;
                end
            endcase
        end
    end
    
    // Extracción de resultado cifrado (primera columna con mod 26)
    always_ff @(posedge clk_clk or negedge reset_reset_n) begin
        if (!reset_reset_n) begin
            for (int i = 0; i < 6; i++) begin
                cipher_result[i] <= 8'b0;
            end
        end else if (current_state == DISPLAY_RESULTS) begin
            for (int i = 0; i < 6; i++) begin
                if (results_valid && results_loaded[i][0] != 32'b0) begin
                    cipher_result[i] <= results_loaded[i][0][7:0];
                end else begin
                    cipher_result[i] <= C_out[i][0][7:0] % 26;
                end
            end
        end
    end
    
    // Selección de palabra para display
    always_comb begin
        case (display_mode)
            4'd0: begin // Palabra original
                display_word = {original_word[5], original_word[4], original_word[3], 
                               original_word[2], original_word[1], original_word[0]};
            end
            4'd1: begin // Palabra cifrada
                display_word = {cipher_result[5], cipher_result[4], cipher_result[3], 
                               cipher_result[2], cipher_result[1], cipher_result[0]};
            end
            4'd2: begin // Performance (solo en hex0-hex3)
                display_word = {16'b0, arithmetic_intensity_x100};
            end
				4'd3: begin // Performance - mostrar operaciones aritméticas
					display_word = {16'b0, arithmetic_ops_counter};
			  end
			  4'd4: begin // Performance - mostrar accesos a memoria
					display_word = {16'b0, memory_accesses_counter};
			  end
			  4'd5: begin // Performance - mostrar ciclos de cómputo
					display_word = {16'b0, compute_cycles};
			  end
            default: begin
                display_word = 48'hDEADBEEFCAFE;
            end
        endcase
    end
    
    // Función de conversión número a letra (0=A, 1=B, etc.)
    function logic [6:0] num_to_letter_7seg(input logic [7:0] num);
        logic [7:0] letter_num;
        letter_num = num % 26; // Asegurar que esté en rango 0-25
        
        case (letter_num)
            8'd0: num_to_letter_7seg = 7'b0001000; // A
            8'd1: num_to_letter_7seg = 7'b0000011; // b
            8'd2: num_to_letter_7seg = 7'b1000110; // C
            8'd3: num_to_letter_7seg = 7'b0100001; // d
            8'd4: num_to_letter_7seg = 7'b0000110; // E
            8'd5: num_to_letter_7seg = 7'b0001110; // F
            8'd6: num_to_letter_7seg = 7'b1000010; // G
            8'd7: num_to_letter_7seg = 7'b0001001; // H
            8'd8: num_to_letter_7seg = 7'b1111001; // I
            8'd9: num_to_letter_7seg = 7'b1100001; // J
            8'd10: num_to_letter_7seg = 7'b0001001; // K (como H)
            8'd11: num_to_letter_7seg = 7'b1000111; // L
            8'd12: num_to_letter_7seg = 7'b1001000; // M
            8'd13: num_to_letter_7seg = 7'b1001000; // N (como M)
            8'd14: num_to_letter_7seg = 7'b1000000; // O
            8'd15: num_to_letter_7seg = 7'b0001100; // P
            8'd16: num_to_letter_7seg = 7'b0011000; // Q
            8'd17: num_to_letter_7seg = 7'b0101111; // r
            8'd18: num_to_letter_7seg = 7'b0010010; // S
            8'd19: num_to_letter_7seg = 7'b0000111; // t
            8'd20: num_to_letter_7seg = 7'b1000001; // U
            8'd21: num_to_letter_7seg = 7'b1000001; // V (como U)
            8'd22: num_to_letter_7seg = 7'b1000001; // W (como U)
            8'd23: num_to_letter_7seg = 7'b0001001; // X (como H)
            8'd24: num_to_letter_7seg = 7'b0010001; // Y
            8'd25: num_to_letter_7seg = 7'b0100100; // Z
            default: num_to_letter_7seg = 7'b1111111; // Apagado
        endcase
    endfunction
    
    // Función de decodificación hexadecimal para números
    function logic [6:0] hex_to_7seg(input logic [3:0] hex);
        case (hex)
            4'h0: hex_to_7seg = 7'b1000000; // 0
            4'h1: hex_to_7seg = 7'b1111001; // 1
            4'h2: hex_to_7seg = 7'b0100100; // 2
            4'h3: hex_to_7seg = 7'b0110000; // 3
            4'h4: hex_to_7seg = 7'b0011001; // 4
            4'h5: hex_to_7seg = 7'b0010010; // 5
            4'h6: hex_to_7seg = 7'b0000010; // 6
            4'h7: hex_to_7seg = 7'b1111000; // 7
            4'h8: hex_to_7seg = 7'b0000000; // 8
            4'h9: hex_to_7seg = 7'b0010000; // 9
            4'hA: hex_to_7seg = 7'b0001000; // A
            4'hB: hex_to_7seg = 7'b0000011; // b
            4'hC: hex_to_7seg = 7'b1000110; // C
            4'hD: hex_to_7seg = 7'b0100001; // d
            4'hE: hex_to_7seg = 7'b0000110; // E
            4'hF: hex_to_7seg = 7'b0001110; // F
            default: hex_to_7seg = 7'b1111111; // Apagado
        endcase
    endfunction
    
    // Asignación de los 6 displays de 7 segmentos
		always_comb begin
			 // Por defecto, apagamos todos
			 hex0 = 7'b1111111;
			 hex1 = 7'b1111111;
			 hex2 = 7'b1111111;
			 hex3 = 7'b1111111;
			 hex4 = 7'b1111111;
			 hex5 = 7'b1111111;

			 case (display_mode)
				  4'd0: begin // Primera columna original (sin cifrar)
						// Invertimos el orden: [47:40] → hex0, … [15:8] → hex5
						hex0 = num_to_letter_7seg(display_word[47:40]); // [0][0]
						hex1 = num_to_letter_7seg(display_word[39:32]); // [1][0]
						hex2 = num_to_letter_7seg(display_word[31:24]); // [2][0]
						hex3 = num_to_letter_7seg(display_word[23:16]); // [3][0]
						hex4 = num_to_letter_7seg(display_word[15:8]);  // [4][0]
						hex5 = num_to_letter_7seg(display_word[7:0]);   // [5][0]
				  end

				  4'd1: begin // Primera columna cifrada
						// Igual inversión
						hex0 = num_to_letter_7seg(display_word[47:40]); // C[0][0]
						hex1 = num_to_letter_7seg(display_word[39:32]); // C[1][0]
						hex2 = num_to_letter_7seg(display_word[31:24]); // …
						hex3 = num_to_letter_7seg(display_word[23:16]);
						hex4 = num_to_letter_7seg(display_word[15:8]);
						hex5 = num_to_letter_7seg(display_word[7:0]);
				  end

				  4'd2: begin // Intensidad aritmética (x100)
						hex0 = hex_to_7seg(display_word[3:0]);   // LSB
						hex1 = hex_to_7seg(display_word[7:4]);
						hex2 = hex_to_7seg(display_word[11:8]);
						hex3 = hex_to_7seg(display_word[15:12]);  // MSB
						// hex4 y hex5 muestran identificador "AI" (Arithmetic Intensity)
						hex4 = 7'b1111001; // A
						hex5 = 7'b0001000; // I
				  end

				  4'd3: begin // Operaciones aritméticas
						hex0 = hex_to_7seg(display_word[3:0]);
						hex1 = hex_to_7seg(display_word[7:4]);
						hex2 = hex_to_7seg(display_word[11:8]);
						hex3 = hex_to_7seg(display_word[15:12]);
						// Identificador "OP" (Operations)
						hex4 = 7'b0001100; // O
						hex5 = 7'b1000000; // P
				  end

				  4'd4: begin // Accesos a memoria
						hex0 = hex_to_7seg(display_word[3:0]);
						hex1 = hex_to_7seg(display_word[7:4]);
						hex2 = hex_to_7seg(display_word[11:8]);
						hex3 = hex_to_7seg(display_word[15:12]);
						// Identificador "ME" (Memory)
						hex4 = 7'b0000110; // M
						hex5 = 7'b1001000; // E
				  end

				  4'd5: begin // Ciclos de cómputo
						hex0 = hex_to_7seg(display_word[3:0]);
						hex1 = hex_to_7seg(display_word[7:4]);
						hex2 = hex_to_7seg(display_word[11:8]);
						hex3 = hex_to_7seg(display_word[15:12]);
						// Identificador "CC" (Compute Cycles)
						hex4 = 7'b1000110; // C
						hex5 = 7'b1000110; // C
				  end

				  default: begin // Debug
						hex0 = hex_to_7seg(display_word[3:0]);
						hex1 = hex_to_7seg(display_word[7:4]);
						hex2 = hex_to_7seg(display_word[11:8]);
						hex3 = hex_to_7seg(display_word[15:12]);
						hex4 = hex_to_7seg(state_debug);
						hex5 = 7'b0000110; // E
				  end
			 endcase
		end


endmodule