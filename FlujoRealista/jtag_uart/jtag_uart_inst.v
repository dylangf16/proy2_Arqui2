	jtag_uart u0 (
		.clk_clk                 (<connected-to-clk_clk>),                 //         clk.clk
		.reset_reset_n           (<connected-to-reset_reset_n>),           //       reset.reset_n
		.jtag_uart_o_chipselect  (<connected-to-jtag_uart_o_chipselect>),  // jtag_uart_o.chipselect
		.jtag_uart_o_address     (<connected-to-jtag_uart_o_address>),     //            .address
		.jtag_uart_o_read_n      (<connected-to-jtag_uart_o_read_n>),      //            .read_n
		.jtag_uart_o_readdata    (<connected-to-jtag_uart_o_readdata>),    //            .readdata
		.jtag_uart_o_write_n     (<connected-to-jtag_uart_o_write_n>),     //            .write_n
		.jtag_uart_o_writedata   (<connected-to-jtag_uart_o_writedata>),   //            .writedata
		.jtag_uart_o_waitrequest (<connected-to-jtag_uart_o_waitrequest>)  //            .waitrequest
	);

