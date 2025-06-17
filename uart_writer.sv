//=========================================================
// UART_HANDSHAKE - FPGA Master esperando handshake
// Espera recibir datos, luego envía "Handshake recibido"
//=========================================================
module uart_writer (
    input  wire        clk,
    input  wire        reset_n,
    output reg         chipselect,
    output reg         address,
    output reg         read_n,
    output reg         write_n,
    output reg [31:0]  writedata,
    input  wire [31:0] readdata,
    input  wire        waitrequest
);

    typedef enum logic [2:0] {
        WAIT_CONNECTION,    // Esperando datos del cliente
        READ_DATA,         // Leyendo datos recibidos
        SEND_RESPONSE,     // Enviando respuesta
        WAIT_SEND,         // Esperando que termine el envío
        SENDING_MESSAGE    // Enviando mensaje completo
    } state_t;
    
    state_t state;

    reg [23:0] poll_counter;        // Contador para polling de recepción
    reg [23:0] send_delay_counter;  // Contador de delay entre caracteres
    reg [4:0]  char_index;         // Índice del carácter a enviar
    reg [7:0]  response_msg [0:18]; // "Handshake recibido\n"
    reg        data_received;       // Flag de datos recibidos

    // Inicializar mensaje de respuesta
    initial begin
        response_msg[0]  = 8'h48; // 'H'
        response_msg[1]  = 8'h61; // 'a' 
        response_msg[2]  = 8'h6E; // 'n'
        response_msg[3]  = 8'h64; // 'd'
        response_msg[4]  = 8'h73; // 's'
        response_msg[5]  = 8'h68; // 'h'
        response_msg[6]  = 8'h61; // 'a'
        response_msg[7]  = 8'h6B; // 'k'
        response_msg[8]  = 8'h65; // 'e'
        response_msg[9]  = 8'h20; // ' '
        response_msg[10] = 8'h72; // 'r'
        response_msg[11] = 8'h65; // 'e'
        response_msg[12] = 8'h63; // 'c'
        response_msg[13] = 8'h69; // 'i'
        response_msg[14] = 8'h62; // 'b'
        response_msg[15] = 8'h69; // 'i'
        response_msg[16] = 8'h64; // 'd'
        response_msg[17] = 8'h6F; // 'o'
        response_msg[18] = 8'h0A; // '\n'
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state            <= WAIT_CONNECTION;
            poll_counter     <= 0;
            send_delay_counter <= 0;
            chipselect       <= 0;
            address          <= 0;
            read_n           <= 1;
            write_n          <= 1;
            writedata        <= 32'd0;
            char_index       <= 0;
            data_received    <= 0;
        end else begin
            case (state)
                WAIT_CONNECTION: begin
                    // Polling periódico para verificar si hay datos
                    chipselect <= 0;
                    write_n    <= 1;
                    
                    if (poll_counter < 24'd50_000) begin // Poll cada ~1ms a 50MHz
                        poll_counter <= poll_counter + 1;
                    end else begin
                        poll_counter <= 0;
                        // Leer el registro de control/status (address = 1)
                        chipselect <= 1;
                        address    <= 1;
                        read_n     <= 0;
                        write_n    <= 1;
                        state      <= READ_DATA;
                    end
                end
                
                READ_DATA: begin
                    if (!waitrequest) begin
                        // Verificar si hay datos disponibles (bit 15 del readdata)
                        if (readdata[15]) begin // RVALID bit
                            data_received <= 1;
                            // Leer el dato actual (address = 0)
                            address <= 0;
                            state   <= SEND_RESPONSE;
                        end else begin
                            // No hay datos, volver a esperar
                            chipselect <= 0;
                            read_n     <= 1;
                            state      <= WAIT_CONNECTION;
                        end
                    end
                end
                
                SEND_RESPONSE: begin
                    if (!waitrequest && data_received) begin
                        // Iniciar envío del mensaje de respuesta
                        chipselect <= 0;
                        read_n     <= 1;
                        char_index <= 0;
                        send_delay_counter <= 0;
                        state      <= SENDING_MESSAGE;
                    end
                end
                
                SENDING_MESSAGE: begin
                    chipselect <= 0;
                    write_n    <= 1;
                    
                    if (send_delay_counter < 24'd100_000) begin // Delay entre caracteres
                        send_delay_counter <= send_delay_counter + 1;
                    end else begin
                        send_delay_counter <= 0;
                        
                        if (char_index < 19) begin // 19 caracteres en total
                            // Enviar carácter actual
                            writedata  <= {24'd0, response_msg[char_index]};
                            chipselect <= 1;
                            write_n    <= 0;
                            address    <= 0; // txdata
                            read_n     <= 1;
                            state      <= WAIT_SEND;
                        end else begin
                            // Mensaje completado, volver a esperar
                            char_index    <= 0;
                            data_received <= 0;
                            state         <= WAIT_CONNECTION;
                        end
                    end
                end
                
                WAIT_SEND: begin
                    if (!waitrequest) begin
                        write_n    <= 1;
                        chipselect <= 0;
                        char_index <= char_index + 1;
                        state      <= SENDING_MESSAGE;
                    end
                end
            endcase
        end
    end

endmodule