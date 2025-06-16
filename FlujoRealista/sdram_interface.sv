// sdram_interface.sv
// Interfaz simplificada para el controlador SDRAM
// Maneja automáticamente las señales de control y temporización

module sdram_interface (
    input  logic           clk,
    input  logic           reset_n,
    
    // Interfaz simplificada hacia el usuario
    input  logic           start_write,    // Pulso para iniciar escritura
    input  logic           start_read,     // Pulso para iniciar lectura
    input  logic [24:0]    address,        // Dirección de memoria
    input  logic [15:0]    write_data,     // Datos a escribir
    output logic [15:0]    read_data,      // Datos leídos
    output logic           operation_done, // Señal de operación completada
    output logic           busy,           // Indica si hay operación en curso
    
    // Conexión hacia el controlador SDRAM
    output logic [24:0]    sdram_address,
    output logic [1:0]     sdram_byteenable_n,
    output logic           sdram_chipselect,
    output logic [15:0]    sdram_writedata,
    output logic           sdram_read_n,
    output logic           sdram_write_n,
    input  logic [15:0]    sdram_readdata,
    input  logic           sdram_readdatavalid,
    input  logic           sdram_waitrequest
);

    // Estados de la máquina de estados
    typedef enum logic [2:0] {
        IDLE,
        WRITE_START,
        WRITE_WAIT,
        READ_START,
        READ_WAIT,
        DONE
    } state_t;
    
    state_t current_state, next_state;
    
    // Registros internos
    logic [24:0] addr_reg;
    logic [15:0] data_reg;
    logic [15:0] read_data_reg;
    logic operation_done_reg;
    
    // Lógica secuencial
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            current_state <= IDLE;
            addr_reg <= 25'b0;
            data_reg <= 16'b0;
            read_data_reg <= 16'b0;
            operation_done_reg <= 1'b0;
        end else begin
            current_state <= next_state;
            
            // Capturar dirección y datos al inicio de operación
            if ((start_write || start_read) && current_state == IDLE) begin
                addr_reg <= address;
                if (start_write) begin
                    data_reg <= write_data;
                end
            end
            
            // Capturar datos leídos cuando están válidos
            if (sdram_readdatavalid) begin
                read_data_reg <= sdram_readdata;
            end
            
            // Controlar señal de operación completada
            operation_done_reg <= (next_state == DONE);
        end
    end
    
    // Lógica combinacional para la máquina de estados
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (start_write) begin
                    next_state = WRITE_START;
                end else if (start_read) begin
                    next_state = READ_START;
                end
            end
            
            WRITE_START: begin
                next_state = WRITE_WAIT;
            end
            
            WRITE_WAIT: begin
                if (!sdram_waitrequest) begin
                    next_state = DONE;
                end
            end
            
            READ_START: begin
                next_state = READ_WAIT;
            end
            
            READ_WAIT: begin
                if (sdram_readdatavalid) begin
                    next_state = DONE;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Asignación de señales hacia el controlador SDRAM
    always_comb begin
        // Valores por defecto (inactivos)
        sdram_address = addr_reg;
        sdram_byteenable_n = 2'b00;  // Ambos bytes habilitados
        sdram_chipselect = 1'b0;
        sdram_writedata = data_reg;
        sdram_read_n = 1'b1;         // Lectura inactiva
        sdram_write_n = 1'b1;        // Escritura inactiva
        
        case (current_state)
            WRITE_START, WRITE_WAIT: begin
                sdram_chipselect = 1'b1;
                sdram_write_n = 1'b0;    // Activar escritura
            end
            
            READ_START, READ_WAIT: begin
                sdram_chipselect = 1'b1;
                sdram_read_n = 1'b0;     // Activar lectura
            end
            
            default: begin
                // Mantener valores por defecto
            end
        endcase
    end
    
    // Asignación de señales hacia el usuario
    assign read_data = read_data_reg;
    assign operation_done = operation_done_reg;
    assign busy = (current_state != IDLE);

endmodule
