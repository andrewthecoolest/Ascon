module uart_tx (
    input wire clk,
    input wire rst,
    input wire tx_start,
    input wire s_tick,
    input wire [7:0] din,
    output reg tx_done_tick,
    output wire tx
);

  // declare states
  localparam [1:0] IDLE  = 2'b00;
  localparam [1:0] START = 2'b01;
  localparam [1:0] DATA  = 2'b10;
  localparam [1:0] STOP  = 2'b11;

  reg [1:0] state;
  reg [3:0] tick_count;
  reg [2:0] bit_count;
  reg [7:0] b_reg;
  reg tx_out;

  always @(posedge clk, posedge rst)
    if (rst) begin
      state <= IDLE;
      tick_count <= 0;
      bit_count <= 0;
      tx_out <= 1;  // uart idle
      b_reg <= 0;
      tx_done_tick <= 0;
    end else begin
      tx_done_tick <= 0;

      case (state)
        IDLE:
        if (tx_start) begin
          state <= START;
          tick_count <= 0;
          b_reg <= din;
        end

        START:
        if (s_tick) begin
          tx_out <= 0;  // set line low to indicate start
          if (tick_count == 15) begin
            state <= DATA;
            tick_count <= 0;
            bit_count <= 0;
          end else tick_count <= tick_count + 1;
        end

        DATA:
        if (s_tick) begin
          tx_out <= b_reg[bit_count];  // hold data for 16 tick
          if (tick_count == 15) begin  // finish last bit
            if (bit_count == 7) state <= STOP;
            tick_count <= 0;
            bit_count  <= bit_count + 1;
          end else tick_count <= tick_count + 1;
        end

        STOP:
        if (s_tick) begin
          tx_out <= 1;
          if (tick_count == 15) begin
            state <= IDLE;
            tick_count <= 0;
            tx_done_tick <= 1;
          end else tick_count <= tick_count + 1;
        end

        default: state <= IDLE;
      endcase
    end

  assign tx = tx_out;

endmodule
