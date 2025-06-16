////////////////////////////////////////////////////////////////////////////////
// jtag_comm.sv
// Módulo de comunicación JTAG UART con handshake simple usando la IP "uart" generada
////////////////////////////////////////////////////////////////////////////////

module jtag_comm (
    input  logic        clk,
    input  logic        reset_n,

    // Status outputs para debug
    output logic        comm_active,      // Indica comunicación activa
    output logic        handshake_done,   // Handshake completado
    output logic [7:0]  last_received,    // Último byte recibido
    output logic [7:0]  status_byte       // Byte de status general
);

    // Estados de la máquina de comunicación
    typedef enum logic [2:0] {
        IDLE,
        WAIT_HELLO,
        SEND_ACK,
        WAIT_ACK_SENT,
        CONNECTED,
        ERROR
    } comm_state_t;

    comm_state_t current_state, next_state;

    // Señales del Avalon JTAG UART
    logic        av_chipselect;
    logic        av_address;      // 0 = data, 1 = control
    logic        av_read_n;
    logic        av_write_n;
    logic [31:0] av_writedata;
    logic [31:0] av_readdata;
    logic        av_waitrequest;

    // Registros internos de lectura/escritura
    logic [7:0]  rx_data;
    logic        data_available;
    logic        write_ready;
    logic [7:0]  tx_data;
    logic        send_byte;
    logic        byte_sent;
    logic        read_state;
    logic        write_state;
    logic        send_requested;
    logic [31:0] control_reg;

    // Constantes para el protocolo de handshake
    localparam logic [7:0] HELLO_BYTE = 8'h48;  // 'H'
    localparam logic [7:0] ACK_BYTE   = 8'h41;  // 'A'

    // -------------------------------------------------------------------------
    // Instanciación de la IP UART generada ('uart')
    // Conecta puertos Avalon a las señales av_*
    uart uart_inst (
        .clk_clk                                      (clk),
        .jtag_uart_0_avalon_jtag_slave_chipselect     (av_chipselect),
        .jtag_uart_0_avalon_jtag_slave_address        (av_address),
        .jtag_uart_0_avalon_jtag_slave_read_n         (av_read_n),
        .jtag_uart_0_avalon_jtag_slave_readdata       (av_readdata),
        .jtag_uart_0_avalon_jtag_slave_write_n        (av_write_n),
        .jtag_uart_0_avalon_jtag_slave_writedata      (av_writedata),
        .jtag_uart_0_avalon_jtag_slave_waitrequest    (av_waitrequest),
        .jtag_uart_0_irq_irq                          (),         // IRQ no usado
        .reset_reset_n                                (reset_n)
    );

    // -------------------------------------------------------------------------
    // Máquina de estados y captura de datos/status
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            current_state <= IDLE;
            last_received <= 8'h00;
            status_byte   <= 8'h00;
        end else begin
            current_state <= next_state;

            if (data_available) last_received <= rx_data;

            case (current_state)
                IDLE:          status_byte <= 8'h01;
                WAIT_HELLO:    status_byte <= 8'h02;
                SEND_ACK:      status_byte <= 8'h03;
                WAIT_ACK_SENT: status_byte <= 8'h04;
                CONNECTED:     status_byte <= 8'h05;
                ERROR:         status_byte <= 8'hFF;
                default:       status_byte <= 8'h00;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Lógica combinacional de transición de estados
    // -------------------------------------------------------------------------
    always_comb begin
        next_state = current_state;
        send_byte  = 1'b0;
        tx_data    = 8'h00;

        case (current_state)
            IDLE:           next_state = WAIT_HELLO;

            WAIT_HELLO:    if (data_available && rx_data == HELLO_BYTE)
                               next_state = SEND_ACK;

            SEND_ACK: begin
                send_byte   = 1'b1;
                tx_data     = ACK_BYTE;
                if (write_ready) next_state = WAIT_ACK_SENT;
            end

            WAIT_ACK_SENT: if (byte_sent) next_state = CONNECTED;

            CONNECTED:    if (data_available && rx_data == HELLO_BYTE)
                               next_state = SEND_ACK;

            ERROR:         next_state = IDLE;
        endcase
    end

    // -------------------------------------------------------------------------
    // Control unificado de lectura/escritura Avalon
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            av_chipselect     <= 1'b0;
            av_address        <= 1'b0;
            av_read_n         <= 1'b1;
            av_write_n        <= 1'b1;
            av_writedata      <= 32'h0;
            data_available    <= 1'b0;
            byte_sent         <= 1'b0;
            write_ready       <= 1'b0;
            read_state        <= 1'b0;
            write_state       <= 1'b0;
            send_requested    <= 1'b0;
            control_reg       <= 32'h0;
            rx_data           <= 8'h00;
        end else begin
            av_chipselect  <= 1'b0;
            av_address     <= 1'b0;
            av_read_n      <= 1'b1;
            av_write_n     <= 1'b1;
            av_writedata   <= 32'h0;
            data_available <= 1'b0;
            byte_sent      <= 1'b0;

            // Lectura
            if (!read_state) begin
                av_chipselect <= 1'b1;
                av_address    <= 1'b1;
                av_read_n     <= 1'b0;
                if (!av_waitrequest) begin
                    control_reg <= av_readdata;
                    read_state  <= 1'b1;
                end
            end else if (control_reg[15:0] > 0) begin
                av_chipselect <= 1'b1;
                av_address    <= 1'b0;
                av_read_n     <= 1'b0;
                if (!av_waitrequest) begin
                    rx_data        <= av_readdata[7:0];
                    data_available <= 1'b1;
                    read_state     <= 1'b0;
                end
            end else begin
                read_state <= 1'b0;
            end

            // Escritura
            if (send_byte && !send_requested) begin
                send_requested <= 1'b1;
                write_ready    <= 1'b0;
            end

            if (send_requested && !write_state) begin
                av_chipselect <= 1'b1;
                av_address    <= 1'b1;
                av_read_n     <= 1'b0;
                if (!av_waitrequest) begin
                    control_reg <= av_readdata;
                    write_state <= 1'b1;
                end
            end else if (write_state && control_reg[31:16] > 0) begin
                av_chipselect <= 1'b1;
                av_address    <= 1'b0;
                av_write_n    <= 1'b0;
                av_writedata  <= {24'h0, tx_data};
                if (!av_waitrequest) begin
                    byte_sent      <= 1'b1;
                    send_requested <= 1'b0;
                    write_ready    <= 1'b1;
                    write_state    <= 1'b0;
                end
            end else begin
                write_ready <= 1'b1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Salidas de debug
    // -------------------------------------------------------------------------
    assign comm_active    = (current_state != IDLE);
    assign handshake_done = (current_state == CONNECTED);

endmodule
