
module jtag_uart (
	clk_clk,
	reset_reset_n,
	jtag_uart_o_chipselect,
	jtag_uart_o_address,
	jtag_uart_o_read_n,
	jtag_uart_o_readdata,
	jtag_uart_o_write_n,
	jtag_uart_o_writedata,
	jtag_uart_o_waitrequest);	

	input		clk_clk;
	input		reset_reset_n;
	input		jtag_uart_o_chipselect;
	input		jtag_uart_o_address;
	input		jtag_uart_o_read_n;
	output	[31:0]	jtag_uart_o_readdata;
	input		jtag_uart_o_write_n;
	input	[31:0]	jtag_uart_o_writedata;
	output		jtag_uart_o_waitrequest;
endmodule
