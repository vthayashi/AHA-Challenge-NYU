`default_nettype none

module aes(
           // Clock and reset.
           input wire           clk,
           input wire           reset_n,

           // Control.
           input wire           cs,
           input wire           we,

           // Data ports.
           input wire  [7 : 0]  address,
           input wire  [31 : 0] write_data,
           output wire [31 : 0] read_data
          );

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  localparam ADDR_NAME0       = 8'h00;
  localparam ADDR_NAME1       = 8'h01;
  localparam ADDR_VERSION     = 8'h02;

  localparam ADDR_CTRL        = 8'h08;
  localparam CTRL_INIT_BIT    = 0;
  localparam CTRL_NEXT_BIT    = 1;

  localparam ADDR_STATUS      = 8'h09;
  localparam STATUS_READY_BIT = 0;
  localparam STATUS_VALID_BIT = 1;

  localparam ADDR_CONFIG      = 8'h0a;
  localparam CTRL_ENCDEC_BIT  = 0;
  localparam CTRL_KEYLEN_BIT  = 1;

  localparam ADDR_KEY0        = 8'h10;
  localparam ADDR_KEY7        = 8'h17;

  localparam ADDR_BLOCK0      = 8'h20;
  localparam ADDR_BLOCK3      = 8'h23;

  localparam ADDR_RESULT0     = 8'h30;
  localparam ADDR_RESULT3     = 8'h33;

  localparam CORE_NAME0       = 32'h61657320; // "aes "
  localparam CORE_NAME1       = 32'h20202020; // "    "
  localparam CORE_VERSION     = 32'h302e3630; // "0.60"


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg init_reg;
  reg init_new;

  reg next_reg;
  reg next_new;

  reg encdec_reg;
  reg keylen_reg;
  reg config_we;

  reg [31 : 0] block_reg [0 : 3];
  reg          block_we;

  reg [31 : 0] key_reg [0 : 7];
  reg          key_we;

  reg [127 : 0] result_reg;
  reg           valid_reg;
  reg           ready_reg;

  reg [9:0] counter_reg;
  reg        halt_reg;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg [31 : 0]   tmp_read_data;

  wire           core_encdec;
  wire           core_init;
  wire           core_next;
  wire           core_ready;
  wire [255 : 0] core_key;
  wire           core_keylen;
  wire [127 : 0] core_block;
  wire [127 : 0] core_result;
  wire           core_valid;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign read_data = tmp_read_data;

  assign core_key = {key_reg[7], key_reg[6], key_reg[5], key_reg[4],
                     key_reg[3], key_reg[2], key_reg[1], key_reg[0]};

  assign core_block  = {block_reg[3], block_reg[2],
                        block_reg[1], block_reg[0]};
  assign core_init   = init_reg & ~halt_reg;
  assign core_next   = next_reg & ~halt_reg;
  assign core_encdec = encdec_reg;
  assign core_keylen = keylen_reg;


  //----------------------------------------------------------------
  // core instantiation.
  //----------------------------------------------------------------
  aes_core core(
                .clk(clk),
                .reset_n(reset_n),

                .encdec(core_encdec),
                .init(core_init),
                .next(core_next),
                .key(core_key),
                .keylen(core_keylen),
                .block(core_block),
                .result(core_result),
                .valid(core_valid),
                .ready(core_ready)
              );

  always @(posedge clk or negedge reset_n) begin
    if (~reset_n) begin
      init_reg       <= 1'b0;
      next_reg       <= 1'b0;
      encdec_reg     <= 1'b0;
      keylen_reg     <= 1'b0;
      block_we       <= 1'b0;
      key_we         <= 1'b0;
      valid_reg      <= 1'b0;
      ready_reg      <= 1'b0;
      counter_reg    <= 10'd0;
      halt_reg       <= 1'b0;
      tmp_read_data  <= 32'd0;
      result_reg     <= 128'd0;
      init_new       <= 1'b0;
      next_new       <= 1'b0;
      config_we      <= 1'b0;
    end else begin
      init_new       <= 1'b0;
      next_new       <= 1'b0;
      config_we      <= 1'b0;
      block_we       <= 1'b0;
      key_we         <= 1'b0;

      if (cs && we) begin
        case (address)
          ADDR_CTRL: begin
            init_new       <= write_data[CTRL_INIT_BIT];
            next_new       <= write_data[CTRL_NEXT_BIT];
          end
          ADDR_CONFIG: begin
            encdec_reg     <= write_data[CTRL_ENCDEC_BIT];
            keylen_reg     <= write_data[CTRL_KEYLEN_BIT];
          end
          ADDR_KEY0, ADDR_KEY1, ADDR_KEY2, ADDR_KEY3, ADDR_KEY4, ADDR_KEY5, ADDR_KEY6, ADDR_KEY7: begin
            key_we         <= 1'b1;
            key_reg[address - ADDR_KEY0] <= write_data;
          end
          ADDR_BLOCK0, ADDR_BLOCK1, ADDR_BLOCK2, ADDR_BLOCK3: begin
            block_we       <= 1'b1;
            block_reg[address - ADDR_BLOCK0] <= write_data;
          end
        endcase
      end

      init_reg       <= init_new;
      next_reg       <= next_new;

      if (core_valid) begin
        result_reg    <= core_result;
        valid_reg     <= 1'b1;
      end

      if (core_ready) begin
        ready_reg     <= 1'b1;
      end

      if (cs && ~we) begin
        case (address)
          ADDR_NAME0: begin
            tmp_read_data <= CORE_NAME0;
          end
          ADDR_NAME1: begin
            tmp_read_data <= CORE_NAME1;
          end
          ADDR_VERSION: begin
            tmp_read_data <= CORE_VERSION;
          end
          ADDR_RESULT0: begin
            tmp_read_data <= result_reg[31:0];
          end
          ADDR_RESULT1: begin
            tmp_read_data <= result_reg[63:32];
          end
          ADDR_RESULT2: begin
            tmp_read_data <= result_reg[95:64];
          end
          ADDR_RESULT3: begin
            tmp_read_data <= result_reg[127:96];
          end
        endcase
      end
    end
  end

endmodule
