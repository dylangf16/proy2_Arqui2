//=========================================================
// TOP MODULE para handshake con JTAG UART
// FPGA: DE1-SoC MTL2 - Master esperando conexión
//=========================================================
module top (
    input  wire CLOCK_50,
    input  wire RESET_N
);

    // Señales JTAG UART
    wire        uart_chipselect;
    wire        uart_address;
    wire        uart_read_n;
    wire [31:0] uart_readdata;
    wire        uart_write_n;
    wire [31:0] uart_writedata;
    wire        uart_waitrequest;

    // Instancia del JTAG UART
    jtag_uart u0 (
        .clk_clk                   (CLOCK_50),
        .reset_reset_n            (RESET_N),
        .jtag_uart_o_chipselect   (uart_chipselect),
        .jtag_uart_o_address      (uart_address),
        .jtag_uart_o_read_n       (uart_read_n),
        .jtag_uart_o_readdata     (uart_readdata),
        .jtag_uart_o_write_n      (uart_write_n),
        .jtag_uart_o_writedata    (uart_writedata),
        .jtag_uart_o_waitrequest  (uart_waitrequest)
    );

    // UART Handshake Master
    uart_writer handshake_master (
        .clk         (CLOCK_50),
        .reset_n     (RESET_N),
        .chipselect  (uart_chipselect),
        .address     (uart_address),
        .read_n      (uart_read_n),
        .write_n     (uart_write_n),
        .writedata   (uart_writedata),
        .readdata    (uart_readdata),
        .waitrequest (uart_waitrequest)
    );

endmodule