`default_nettype none

module wbuart_tb;

reg i_clk;
reg i_reset_n;
reg i_wb_cyc;
reg i_wb_stb;
reg i_wb_we;
reg [1:0] i_wb_addr;
reg [31:0] i_wb_data;
reg [3:0] i_wb_sel;
wire o_wb_stall;
reg o_wb_ack;
reg [31:0] o_wb_data;
reg i_uart_rx;
wire o_uart_tx;
reg i_cts_n;
reg o_rts_n;
wire o_uart_rx_int;
wire o_uart_tx_int;
wire o_uart_rxfifo_int;
wire o_uart_txfifo_int;

wbuart uut (
    .i_clk(i_clk),
    .i_reset_n(i_reset_n),
    .i_wb_cyc(i_wb_cyc),
    .i_wb_stb(i_wb_stb),
    .i_wb_we(i_wb_we),
    .i_wb_addr(i_wb_addr),
    .i_wb_data(i_wb_data),
    .i_wb_sel(i_wb_sel),
    .o_wb_stall(o_wb_stall),
    .o_wb_ack(o_wb_ack),
    .o_wb_data(o_wb_data),
    .i_uart_rx(i_uart_rx),
    .o_uart_tx(o_uart_tx),
    .i_cts_n(i_cts_n),
    .o_rts_n(o_rts_n),
    .o_uart_rx_int(o_uart_rx_int),
    .o_uart_tx_int(o_uart_tx_int),
    .o_uart_rxfifo_int(o_uart_rxfifo_int),
    .o_uart_txfifo_int(o_uart_txfifo_int)
);

initial begin
    i_clk = 0;
    forever #5 i_clk = ~i_clk;
end

initial begin
    i_reset_n = 0;
    #10;
    i_reset_n = 1;
    #10;
    i_wb_cyc = 1;
    i_wb_stb = 1;
    i_wb_we = 1;
    i_wb_addr = 2'b00;
    i_wb_data = 32'h00000001;
    i_wb_sel = 4'b1111;
    #10;
    i_wb_we = 0;
    #10;
    i_wb_stb = 0;
    #10;
    i_wb_cyc = 0;
    #10;
    i_uart_rx = 1;
    #10;
    i_uart_rx = 0;
    #10;
    i_cts_n = 0;
    #10;
    i_cts_n = 1;
    #100;
    $finish;
end

endmodule
