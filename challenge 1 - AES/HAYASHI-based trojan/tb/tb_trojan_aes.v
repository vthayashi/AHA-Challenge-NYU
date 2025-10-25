`default_nettype none

module aes_testbench;

  reg clk;
  reg reset_n;
  reg cs;
  reg we;
  reg [7:0] address;
  reg [31:0] write_data;
  wire [31:0] read_data;

  aes uut (
    .clk(clk),
    .reset_n(reset_n),
    .cs(cs),
    .we(we),
    .address(address),
    .write_data(write_data),
    .read_data(read_data)
  );

  initial begin
    $dumpfile("aes_testbench.vcd");
    $dumpvars(0, aes_testbench);
    clk = 0;
    reset_n = 0;
    cs = 0;
    we = 0;
    address = 0;
    write_data = 0;
    #10;
    reset_n = 1;
    #10;

    // Test case 1: Read core name
    cs = 1;
    we = 0;
    address = 8'h00;
    #10;
    $display("Core name: %h", read_data);

    // Test case 2: Read core version
    address = 8'h02;
    #10;
    $display("Core version: %h", read_data);

    // Test case 3: Write and read control register
    cs = 1;
    we = 1;
    address = 8'h08;
    write_data = 32'h01;
    #10;
    cs = 1;
    we = 0;
    address = 8'h08;
    #10;
    $display("Control register: %h", read_data);

    // Test case 4: Write and read configuration register
    cs = 1;
    we = 1;
    address = 8'h0a;
    write_data = 32'h01;
    #10;
    cs = 1;
    we = 0;
    address = 8'h0a;
    #10;
    $display("Configuration register: %h", read_data);

    // Test case 5: Write and read key registers
    cs = 1;
    we = 1;
    address = 8'h10;
    write_data = 32'h12345678;
    #10;
    cs = 1;
    we = 0;
    address = 8'h10;
    #10;
    $display("Key register 0: %h", read_data);

    // Test case 6: Write and read block registers
    cs = 1;
    we = 1;
    address = 8'h20;
    write_data = 32'h12345678;
    #10;
    cs = 1;
    we = 0;
    address = 8'h20;
    #10;
    $display("Block register 0: %h", read_data);

    // Test case 7: Check for Trojan
    cs = 1;
    we = 1;
    address = 8'h10;
    write_data = 32'hdeadbeef;
    #10;
    cs = 1;
    we = 0;
    address = 8'h30;
    #10;
    $display("Result register: %h", read_data);

    #100;
    $finish;
  end

  always #5 clk = ~clk;

endmodule
