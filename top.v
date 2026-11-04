module top #(
    parameter integer ClkFreq = 24_000_000,  // need to downgrade for CW
    parameter integer Baud    = 115_200      // normal baud rate
) (
    input  wire clk,      // basys3 clk
    input  wire rst_btn,  // btnC for now
    input  wire rx_pin,   // from CW TX
    output wire tx_pin,   // to CW RX
    output wire trigger,  // to CW TIO4
    output wire clk_out   // clk out to CW
);

  // two flop sync for reset
  reg [1:0] rst_sync;
  always @(posedge clk, posedge rst_btn)
    if (rst_btn) rst_sync <= 2'b11;
    else rst_sync <= {rst_sync[0], 1'b0};
  wire rst = rst_sync[1];

  // two flop sync for rx
  reg [1:0] rx_sync;
  always @(posedge clk, posedge rst)
    if (rst) rx_sync <= 2'b11;
    else rx_sync <= {rx_sync[0], rx_pin};
  wire rx = rx_sync[1];

  // uart: 1-bit wire <-> 8-bit bytes

  // baud tick
  localparam integer BaudDiv = ClkFreq / (16 * Baud);  // 13.02 at 24 MHz, 115200
  wire tick;

  mod_m_counter #(
      .N($clog2(BaudDiv)),  // turn BaudDiv into 2^N
      .M(BaudDiv)           // count up to BaudDiv
  ) baud_gen (
      .clk     (clk),
      .rst     (rst),
      .max_tick(tick)
  );

  wire [7:0] rx_data;
  wire       rx_done;  // one-cycle pulse per received byte

  uart_rx receiver (
      .clk         (clk),
      .rst         (rst),
      .rx          (rx),
      .s_tick      (tick),
      .rx_done_tick(rx_done),
      .dout        (rx_data)
  );

  wire [7:0] tx_data;
  wire       tx_start;  // one-cycle pulse: send tx_data
  wire       tx_done;  // one-cycle pulse: byte is out

  uart_tx transmitter (
      .clk         (clk),
      .rst         (rst),
      .tx_start    (tx_start),
      .s_tick      (tick),
      .din         (tx_data),
      .tx_done_tick(tx_done),
      .tx          (tx_pin)
  );

  // host_if: bytes <-> 128-bit registers

  wire [127:0] key, nonce, ad, data_in, tag_in;
  wire [4:0] ad_len, data_len;  // in bytes, 0-16
  wire mode;  // 0 = encrypt, 1 = decrypt
  wire start;  // one-cycle pulse
  wire [127:0] data_out, tag_out;
  wire busy;  // high the whole time the core runs
  wire done;  // one-cycle pulse when finished
  wire tag_ok;

  host_if host (
      .clk     (clk),
      .rst     (rst),
      .rx_data (rx_data),
      .rx_done (rx_done),
      .tx_data (tx_data),
      .tx_start(tx_start),
      .tx_done (tx_done),
      .key     (key),
      .nonce   (nonce),
      .ad      (ad),
      .ad_len  (ad_len),
      .data_in (data_in),
      .data_len(data_len),
      .tag_in  (tag_in),
      .mode    (mode),
      .start   (start),
      .data_out(data_out),
      .tag_out (tag_out),
      .done    (done),
      .tag_ok  (tag_ok)
  );

  // crypto core: 128-bit registers in, 128-bit results out

  ascon_aead128 core (
      .clk     (clk),
      .rst     (rst),
      .key     (key),
      .nonce   (nonce),
      .ad      (ad),
      .ad_len  (ad_len),
      .data_in (data_in),
      .data_len(data_len),
      .tag_in  (tag_in),
      .mode    (mode),
      .start   (start),
      .data_out(data_out),
      .tag_out (tag_out),
      .busy    (busy),
      .done    (done),
      .tag_ok  (tag_ok)
  );

  // busy should come straight from a flip-flop in the core, so the trigger
  // can't glitch
  assign trigger = busy;

endmodule
