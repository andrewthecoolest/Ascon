module uart_rx (
    input wire clk,
    input wire rst,
    input wire rx,
    input wire s_tick,
    output reg rx_done_tick,
    output wire [7:0] dout
);

  // 8N1 frame on the wire:
  // idle high, start low, d0, d1, ..., d7, stop high

  // states
  localparam [1:0] IDLE  = 2'd0;
  localparam [1:0] START = 2'd1;
  localparam [1:0] DATA  = 2'd2;
  localparam [1:0] STOP  = 2'd3;

  reg [1:0] state;
  reg [3:0] tick_count;  // counts s_tick pulse
  reg [2:0] bit_count;  // track curr bit
  reg [7:0] data;

  always @(posedge clk, posedge rst)
    if (rst) begin
      state        <= IDLE;
      tick_count   <= 0;
      bit_count    <= 0;
      data         <= 0;
      rx_done_tick <= 0;
    end else begin
      rx_done_tick <= 0;  // default: no pulse

      case (state)
        // wait for low
        IDLE:
        if (rx == 0) begin
          tick_count <= 0;
          state      <= START;
        end

        // go to the middle of 16 tick
        START:
        if (s_tick) begin
          if (tick_count == 7) begin
            tick_count <= 0;
            bit_count  <= 0;
            state      <= DATA;
          end else tick_count <= tick_count + 1;
        end

        // get data
        DATA:
        if (s_tick) begin
          if (tick_count == 15) begin
            tick_count <= 0;
            data       <= {rx, data[7:1]};  // shift in, LSB arrives first
            if (bit_count == 7) state <= STOP;
            else bit_count <= bit_count + 1;
          end else tick_count <= tick_count + 1;
        end

        // wait through the stop bit, then post done
        STOP:
        if (s_tick) begin
          if (tick_count == 15) begin
            rx_done_tick <= 1;
            state        <= IDLE;
          end else tick_count <= tick_count + 1;
        end

        // just like IDLE
        default:
        if (rx == 0) begin
          tick_count <= 0;
          state      <= START;
        end

      endcase
    end

  assign dout = data;

endmodule
