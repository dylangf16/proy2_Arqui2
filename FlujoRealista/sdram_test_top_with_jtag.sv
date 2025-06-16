// sdram_test_top_with_jtag.sv
// Top level con comunicación JTAG integrada

module sdram_test_top_with_jtag (
    input  logic           clk_clk,
    input  logic           reset_reset_n,
    
    // Pines físicos hacia la SDRAM (conduit "wire_*")
    output logic [12:0]    wire_addr,
    output logic [1:0]     wire_ba,
    output logic           wire_cas_n,
    output logic           wire_cke,
    output logic           wire_cs_n,
    inout  logic [15:0]    wire_dq,
    output logic [1:0]     wire_dqm,
    output logic           wire_ras_n,
    output logic           wire_we_n,
    
    // Display de 7 segmentos (4 dígitos para más info)
    output logic [6:0]     hex0,           // Status de comunicación
    output logic [6:0]     hex1,           // Último byte recibido (low nibble)
    output logic [6:0]     hex2,           // Último byte recibido (high nibble)
    output logic [6:0]     hex3,           // Estado general
    
    // LEDs para debug visual
    output logic [9:0]     ledr           // LEDs rojos para status
);

    // Señales internas del controlador SDRAM (sin cambios)
    logic [24:0] sdram_address;
    logic [1:0]  sdram_byteenable_n;
    logic        sdram_chipselect;
    logic [15:0] sdram_writedata;
    logic        sdram_read_n;
    logic        sdram_write_n;
    logic [15:0] sdram_readdata;
    logic        sdram_readdatavalid;
    logic        sdram_waitrequest;
    
    // Señales de la interfaz SDRAM simplificada (sin cambios)
    logic        start_write;
    logic        start_read; 
    logic [24:0] address;
    logic [15:0] write_data;
    logic [15:0] read_data;
    logic        operation_done;
    logic        busy;
    
    // Señales del módulo de comunicación JTAG
    logic        comm_active;
    logic        handshake_done;
    logic [7:0]  last_received;
    logic [7:0]  status_byte;
    
    // Máquina de estados para el test (modificada)
    typedef enum logic [3:0] {
        INIT,
        WAIT_COMM,           // Nuevo: esperar comunicación
        COMM_ESTABLISHED,    // Nuevo: comunicación establecida
        WRITE_SETUP,
        WRITE_EXECUTE,
        WRITE_WAIT,
        READ_SETUP,
        READ_EXECUTE,
        READ_WAIT,
        DISPLAY
    } test_state_t;
    
    test_state_t current_test_state, next_test_state;
    
    // Contadores y registros
    logic [25:0] delay_counter;
    logic [15:0] display_value;
    logic        delay_done;
    
    // Valores de prueba
    localparam logic [24:0] TEST_ADDRESS = 25'h100000;
    localparam logic [15:0] TEST_DATA = 16'h0042;
    
    // Instanciación del controlador SDRAM (sin cambios)
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
    
    // Instanciación de la interfaz SDRAM simplificada (sin cambios)
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
    
    // Instanciación del módulo de comunicación JTAG (NUEVO)
    jtag_comm jtag_comm_inst (
        .clk(clk_clk),
        .reset_n(reset_reset_n),
        .comm_active(comm_active),
        .handshake_done(handshake_done),
        .last_received(last_received),
        .status_byte(status_byte)
    );
    
    // Contador de delay (sin cambios)
    always_ff @(posedge clk_clk or negedge reset_reset_n) begin
        if (!reset_reset_n) begin
            delay_counter <= 26'b0;
            delay_done <= 1'b0;
        end else begin
            if (delay_counter < 26'd50000000) begin  // ~1 segundo a 50MHz
                delay_counter <= delay_counter + 1;
            end else begin
                delay_done <= 1'b1;
            end
        end
    end
    
    // Máquina de estados modificada para incluir comunicación
    always_ff @(posedge clk_clk or negedge reset_reset_n) begin
        if (!reset_reset_n) begin
            current_test_state <= INIT;
            display_value <= 16'b0;
        end else begin
            current_test_state <= next_test_state;
            
            // Capturar el valor leído para el display
            if (current_test_state == READ_WAIT && operation_done) begin
                display_value <= read_data;
            end
        end
    end
    
    // Lógica de la máquina de estados (modificada)
    always_comb begin
        next_test_state = current_test_state;
        start_write = 1'b0;
        start_read = 1'b0;
        address = TEST_ADDRESS;
        write_data = TEST_DATA;
        
        case (current_test_state)
            INIT: begin
                if (delay_done) begin
                    next_test_state = WAIT_COMM;
                end
            end
            
            WAIT_COMM: begin
                if (handshake_done) begin
                    next_test_state = COMM_ESTABLISHED;
                end
            end
            
            COMM_ESTABLISHED: begin
                // Por ahora, proceder automáticamente al test
                // Más tarde aquí esperaremos comandos del PC
                next_test_state = WRITE_SETUP;
            end
            
            WRITE_SETUP: begin
                next_test_state = WRITE_EXECUTE;
            end
            
            WRITE_EXECUTE: begin
                start_write = 1'b1;
                next_test_state = WRITE_WAIT;
            end
            
            WRITE_WAIT: begin
                if (operation_done) begin
                    next_test_state = READ_SETUP;
                end
            end
            
            READ_SETUP: begin
                next_test_state = READ_EXECUTE;
            end
            
            READ_EXECUTE: begin
                start_read = 1'b1;
                next_test_state = READ_WAIT;
            end
            
            READ_WAIT: begin
                if (operation_done) begin
                    next_test_state = DISPLAY;
                end
            end
            
            DISPLAY: begin
                // Mantener el valor en el display
                next_test_state = DISPLAY;
            end
            
            default: begin
                next_test_state = INIT;
            end
        endcase
    end
    
    // Decodificador de 7 segmentos (sin cambios)
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
        endcase
    endfunction
    
    // Asignación de los displays de 7 segmentos (modificada para debug)
    assign hex0 = hex_to_7seg(status_byte[3:0]);      // Status de comunicación (low)
    assign hex1 = hex_to_7seg(status_byte[7:4]);      // Status de comunicación (high)
    assign hex2 = hex_to_7seg(last_received[3:0]);    // Último byte recibido (low)
    assign hex3 = hex_to_7seg(last_received[7:4]);    // Último byte recibido (high)
    
    // Asignación de LEDs para debug visual
    assign ledr[0] = comm_active;                     // LED0: comunicación activa
    assign ledr[1] = handshake_done;                  // LED1: handshake completado
    assign ledr[2] = busy;                            // LED2: SDRAM ocupada
    assign ledr[3] = (current_test_state == DISPLAY);// LED3: en estado display
    assign ledr[4] = (current_test_state == WAIT_COMM); // LED4: esperando comunicación
	 assign ledr[8:5] = current_test_state; 
	 
endmodule