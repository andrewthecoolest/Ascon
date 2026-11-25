module ascon_aead128 (
    input wire clk,
    input wire rst,

    input wire [255:0] key,  // 2 shares, share 0 is key[127:0]
    input wire [127:0] nonce,

    input wire [127:0] ad,
    input wire [  4:0] ad_len,  // in bytes, 0-16

    input wire [127:0] data_in,
    input wire [  4:0] data_len,  // in bytes, 0-16

    input wire [127:0] tag_in,

    input wire mode,  // 0 = encrypt, 1 = decrypt
    input wire start,  // one-cycle pulse

    input wire [319:0] z,  // fresh randomness, new every cycle

    output wire [127:0] data_out,
    output wire [127:0] tag_out,
    output wire busy,  // high the whole time the core runs
    output wire done,  // one-cycle pulse when finished
    output wire tag_ok
);

  // state declaration
  localparam [3:0] Idle = 4'd0;
  localparam [3:0] Perm = 4'd1;  // pulse load
  localparam [3:0] PermWait = 4'd2;  // wait for idle
  localparam [3:0] InitKey = 4'd3;
  localparam [3:0] Ad = 4'd4;
  localparam [3:0] AdPad = 4'd5;  // ad_len = 16
  localparam [3:0] DomainSep = 4'd6;
  localparam [3:0] Data = 4'd7;
  localparam [3:0] DataPad = 4'd8;  // data_len = 16
  localparam [3:0] Final = 4'd9;
  localparam [3:0] Tag = 4'd10;

  // mode declaration, decrypt is the else case
  localparam Encrypt = 1'b0;

  localparam [63:0] IV = 64'h00001000808c0001;

  reg [3:0] curr;  // state of FSM
  reg [3:0] after;  // next state after permutation

  // ascon state, 2 shares of 320 bits: {share 1, share 0}
  // S0 of share 0 is s[63:0], of share 1 is s[383:320]
  // public values (IV, nonce, ad, data, constants) only go into share 0
  reg [639:0] s;
  wire [639:0] s_w;  // permutation result

  // key shares, refreshed on every start so they differ each run
  reg [255:0] k;
  wire [255:0] k_new = {key[255:128] ^ z[127:0], key[127:0] ^ z[127:0]};

  // permutation signals
  reg [3:0] rnds;
  wire load = (curr == Perm);
  wire idle;

  ascon_permutation permutation (
      .clk  (clk),
      .rst  (rst),
      .load (load),
      .rnds (rnds),
      .z    (z),
      .s_in (s),
      .s_out(s_w),
      .idle (idle)
  );

  // output registers
  reg [127:0] data_out_reg, tag_out_reg;
  reg busy_reg, done_reg, tag_ok_reg;

  // padding: len bytes, then 0x01, then zeros
  wire [127:0] ad_mask = ~({128{1'b1}} << (8 * ad_len));
  wire [127:0] ad_pad = 128'd1 << (8 * ad_len);
  wire [127:0] data_mask = ~({128{1'b1}} << (8 * data_len));
  wire [127:0] data_pad = 128'd1 << (8 * data_len);

  // plaintext, one share at a time. data_in is public so it goes in share 0
  wire [127:0] pt_0 = ((mode == Encrypt) ? data_in : data_in ^ s[127:0]) & data_mask;
  wire [127:0] pt_1 = ((mode == Encrypt) ? 128'd0 : s[447:320]) & data_mask;

  // tag, shares put back together. the tag is public
  wire [127:0] tag = s[319:192] ^ s[639:512] ^ k[127:0] ^ k[255:128];

  always @(posedge clk, posedge rst)
    if (rst) begin
      curr         <= Idle;
      after        <= Idle;
      s            <= 640'd0;
      k            <= 256'd0;
      rnds         <= 4'd0;
      data_out_reg <= 128'd0;
      tag_out_reg  <= 128'd0;
      busy_reg     <= 1'b0;
      done_reg     <= 1'b0;
      tag_ok_reg   <= 1'b0;
    end else begin
      done_reg <= 1'b0;  // default: no pulse
      case (curr)
        Idle:
        if (start) begin
          s        <= {128'd0, k_new[255:128], 64'd0, nonce, k_new[127:0], IV};
          k        <= k_new;
          rnds     <= 12;
          after    <= InitKey;
          busy_reg <= 1'b1;
          curr     <= Perm;
        end

        Perm: curr <= PermWait;

        PermWait:
        if (idle) begin
          s    <= s_w;
          curr <= after;
        end

        InitKey: begin
          s[319:192] <= s[319:192] ^ k[127:0];
          s[639:512] <= s[639:512] ^ k[255:128];
          curr <= (ad_len != 0) ? Ad : DomainSep;  // skip empty AD
        end

        Ad: begin
          s[127:0] <= s[127:0] ^ (ad & ad_mask) ^ ad_pad;
          rnds     <= 8;
          after    <= (ad_len == 16) ? AdPad : DomainSep;
          curr     <= Perm;
        end

        AdPad: begin
          s[127:0] <= s[127:0] ^ 128'd1;
          rnds     <= 8;
          after    <= DomainSep;
          curr     <= Perm;
        end

        DomainSep: begin
          s[319] <= ~s[319];
          curr   <= Data;
        end

        Data: begin
          // shares put back together, ciphertext is public
          // decrypted plaintext is not protected (only the key is)
          data_out_reg <= (s[127:0] ^ s[447:320] ^ data_in) & data_mask;
          s[127:0] <= s[127:0] ^ pt_0 ^ data_pad;
          s[447:320] <= s[447:320] ^ pt_1;
          if (data_len == 16) begin
            rnds  <= 8;
            after <= DataPad;
            curr  <= Perm;
          end else curr <= Final;
        end

        DataPad: begin  // no permutation
          s[127:0] <= s[127:0] ^ 128'd1;
          curr     <= Final;
        end

        Final: begin
          s[255:128] <= s[255:128] ^ k[127:0];
          s[575:448] <= s[575:448] ^ k[255:128];
          rnds       <= 12;
          after      <= Tag;
          curr       <= Perm;
        end

        Tag: begin
          tag_out_reg <= tag;
          tag_ok_reg  <= (tag == tag_in);
          busy_reg    <= 1'b0;
          done_reg    <= 1'b1;
          curr        <= Idle;
        end

        default: curr <= Idle;
      endcase
    end

  assign data_out = data_out_reg;
  assign tag_out  = tag_out_reg;
  assign busy     = busy_reg;
  assign done     = done_reg;
  assign tag_ok   = tag_ok_reg;

endmodule
