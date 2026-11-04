module host_if (
    input wire clk,
    input wire rst,

    // uart rx side
    input wire [7:0] rx_data,
    input wire       rx_done,  // one-cycle pulse per received byte

    // uart tx side
    output wire [7:0] tx_data,
    output wire       tx_start,  // one-cycle pulse: send tx_data
    input  wire       tx_done,   // one-cycle pulse: byte is out

    // to crypto core
    output wire [127:0] key,
    output wire [127:0] nonce,
    output wire [127:0] ad,
    output wire [  4:0] ad_len,    // in bytes, 0-16
    output wire [127:0] data_in,
    output wire [  4:0] data_len,  // in bytes, 0-16
    output wire [127:0] tag_in,
    output wire         mode,      // 0 = encrypt, 1 = decrypt
    output wire         start,     // one-cycle pulse

    // from crypto core
    input wire [127:0] data_out,
    input wire [127:0] tag_out,
    input wire         done,      // one-cycle pulse when finished
    input wire         tag_ok
);

  // command codes
  localparam [7:0] CmdKey   = 8'h01; // then 16 bytes
  localparam [7:0] CmdNonce = 8'h02; // then 16 bytes
  localparam [7:0] CmdAD    = 8'h03; // then len, then len bytes
  localparam [7:0] CmdData  = 8'h04; // then len, then len bytes
  localparam [7:0] CmdTag   = 8'h05; // then 16 bytes
  localparam [7:0] CmdRun   = 8'h06; // then 1 mode byte

  // states
  localparam [2:0] Idle = 3'b000; // next byte is a command
  localparam [2:0] Len  = 3'b001; // next byte is a length
  localparam [2:0] Data = 3'b010; // next bytes go into the register cmd picks
  localparam [2:0] Run  = 3'b011; // next byte is mode, then pulse start
  localparam [2:0] Wait = 3'b100; // wait for done from the core
  localparam [2:0] Send = 3'b101; // put one byte on tx, pulse tx_start
  localparam [2:0] SendWait = 3'b110; // wait for tx_done, then next byte

  reg [2:0] state;
  reg [7:0] cmd;
  reg [4:0] len;  // how many data bytes to read
  reg [4:0] count;  // how many data bytes read
  reg mode_reg;
  reg start_reg;

  reg [4:0] ad_len_reg, data_len_reg;
  reg [127:0] key_reg, tag_reg, nonce_reg, ad_reg, data_reg;

  reg [5:0] send_count;  // which reply byte
  reg [5:0] send_len;  // how many reply bytes in total
  reg [7:0] tx_data_reg;
  reg tx_start_reg;

  // pick reply byte number send_count
  reg [7:0] send_byte;
  always @* begin
    if (mode_reg == 0) begin  // encrypt
      if (send_count < data_len_reg) send_byte = data_out[send_count*8+:8];
      else send_byte = tag_out[(send_count-data_len_reg)*8+:8];
    end else begin  // decrypt
      if (send_count == 0) send_byte = {7'b0, tag_ok};
      else send_byte = data_out[(send_count-1)*8+:8];
    end
  end

  always @(posedge clk, posedge rst)
    if (rst) begin
      state        <= Idle;
      cmd          <= 0;
      len          <= 0;
      count        <= 0;
      mode_reg     <= 0;
      start_reg    <= 0;
      ad_len_reg   <= 0;
      data_len_reg <= 0;
      key_reg      <= 0;
      tag_reg      <= 0;
      nonce_reg    <= 0;
      ad_reg       <= 0;
      data_reg     <= 0;
      send_count   <= 0;
      send_len     <= 0;
      tx_data_reg  <= 0;
      tx_start_reg <= 0;
    end else begin
      start_reg <= 0;
      tx_start_reg <= 0;
      case (state)
        Idle:
        if (rx_done) begin
          cmd <= rx_data;  // read cmd, pick next state
          case (rx_data)
            CmdKey, CmdNonce, CmdTag: begin
              len   <= 16;
              count <= 0;
              state <= Data;
            end
            CmdAD, CmdData: state <= Len;
            CmdRun: state <= Run;
            default: cmd <= 0;
          endcase
        end

        Len:  // read len
        if (rx_done) begin
          if (rx_data > 16) begin  // bad length
            cmd   <= 0;
            state <= Idle;
          end else begin
            len   <= rx_data[4:0];
            count <= 0;
            case (cmd)
              CmdAD:   ad_len_reg <= rx_data[4:0];
              CmdData: data_len_reg <= rx_data[4:0];
              default: ;
            endcase
            state <= (rx_data == 0) ? Idle : Data;
          end
        end

        Data:
        if (rx_done) begin
          case (cmd)
            CmdKey:   key_reg  [count*8 +: 8] <= rx_data;
            CmdNonce: nonce_reg[count*8 +: 8] <= rx_data;
            CmdTag:   tag_reg  [count*8 +: 8] <= rx_data;
            CmdAD:    ad_reg   [count*8 +: 8] <= rx_data;
            CmdData:  data_reg [count*8 +: 8] <= rx_data;
            default: ;
          endcase
          count <= count + 1;
          if (count >= len - 1) state <= Idle;
        end

        Run:  // read mode, pulse start
        if (rx_done) begin
          if (rx_data > 1) begin  // bad mode
            cmd   <= 0;
            state <= Idle;
          end else begin
            mode_reg  <= rx_data[0];
            start_reg <= 1;
            state     <= Wait;
          end
        end

        Wait:  // wait for done
        if (done) begin
          send_count <= 0;
          send_len   <= (mode_reg == 0) ? data_len_reg + 16 : data_len_reg + 1;
          state      <= Send;
        end

        Send: begin  // put byte on tx, pulse tx_start
          tx_data_reg  <= send_byte;
          tx_start_reg <= 1;
          state        <= SendWait;
        end

        SendWait:  // byte is going out, wait for it to finish
        if (tx_done) begin
          if (send_count == send_len - 1) state <= Idle;  // last byte done
          else begin
            send_count <= send_count + 1;
            state      <= Send;
          end
        end

        default: state <= Idle;
      endcase
    end

  assign ad_len = ad_len_reg;
  assign data_len = data_len_reg;

  assign key = key_reg;
  assign tag_in = tag_reg;
  assign nonce = nonce_reg;
  assign data_in = data_reg;
  assign ad = ad_reg;

  assign mode = mode_reg;
  assign start = start_reg;

  assign tx_data = tx_data_reg;
  assign tx_start = tx_start_reg;

endmodule
