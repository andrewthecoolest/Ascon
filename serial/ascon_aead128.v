module ascon_aead128 (
    input wire clk,
    input wire rst,

    input wire [127:0] key,
    input wire [127:0] nonce,

    input wire [127:0] ad,
    input wire [  4:0] ad_len,  // in bytes, 0-16

    input wire [127:0] data_in,
    input wire [  4:0] data_len,  // in bytes, 0-16

    input wire [127:0] tag_in,

    input wire mode,  // 0 = encrypt, 1 = decrypt
    input wire start,  // one-cycle pulse

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
  localparam [3:0] Load = 4'd11;  // s <= {nonce, key, IV}

  // one thing per tick: every 64-bit move or xor below takes one lane per
  // tick, counted by lane. busy timing from the trigger (edge 0 = start),
  // empty ad and data:
  //   edges 1-5      core s <= IV, key lo, key hi, nonce lo, nonce hi
  //   edge 6         load pulse
  //   edges 7-11     permutation s <= core s, one lane per tick
  //   edges 12-851   12 rounds, 70 ticks each. round r starts at 12+70(r-1):
  //                    +0 round constant, +1+i sbox column i, +65+j diffusion lane j
  //   edges 852-856  core s <= result, one lane per tick
  //   ...            then initkey, domain sep, data, final, p12, tag

  // mode declaration, decrypt is the else case
  localparam Encrypt = 1'b0;

  localparam [63:0] IV = 64'h00001000808c0001;

  reg [3:0] curr;  // state of FSM
  reg [3:0] after;  // next state after permutation
  reg [2:0] lane;  // lane written this tick, in states that take several ticks

  // ascon state, S0 is s[63:0]
  reg [319:0] s;
  wire [319:0] s_w;  // permutation result

  // permutation signals
  reg [3:0] rnds;
  wire load = (curr == Perm);
  wire idle;

  ascon_permutation permutation (
      .clk  (clk),
      .rst  (rst),
      .load (load),
      .rnds (rnds),
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

  // plaintext
  wire [127:0] pt = ((mode == Encrypt) ? data_in : data_in ^ s[127:0]) & data_mask;

  // whole-word values, written below one lane per tick
  wire [319:0] init = {nonce, key, IV};
  wire [127:0] ad_blk = (ad & ad_mask) ^ ad_pad;
  wire [127:0] ct = (s[127:0] ^ data_in) & data_mask;
  wire [127:0] data_blk = pt ^ data_pad;
  wire last = (lane == 3'd1);  // second lane of a 128-bit word

  always @(posedge clk, posedge rst)
    if (rst) begin
      curr         <= Idle;
      after        <= Idle;
      s            <= 320'd0;
      rnds         <= 4'd0;
      lane         <= 3'd0;
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
          lane     <= 0;
          busy_reg <= 1'b1;
          curr     <= Load;
        end

        Load: begin  // IV, key lo, key hi, nonce lo, nonce hi
          s[64*lane+:64] <= init[64*lane+:64];
          if (lane == 4) begin
            lane  <= 0;
            rnds  <= 12;
            after <= InitKey;
            curr  <= Perm;
          end else lane <= lane + 1;
        end

        Perm: curr <= PermWait;

        PermWait:
        if (idle) begin  // copy the result back, one lane per tick
          s[64*lane+:64] <= s_w[64*lane+:64];
          if (lane == 4) begin
            lane <= 0;
            curr <= after;
          end else lane <= lane + 1;
        end

        InitKey: begin  // key into S3, S4
          s[192+64*lane+:64] <= s[192+64*lane+:64] ^ key[64*lane+:64];
          if (last) begin
            lane <= 0;
            curr <= (ad_len != 0) ? Ad : DomainSep;  // skip empty AD
          end else lane <= lane + 1;
        end

        Ad: begin
          s[64*lane+:64] <= s[64*lane+:64] ^ ad_blk[64*lane+:64];
          if (last) begin
            lane  <= 0;
            rnds  <= 8;
            after <= (ad_len == 16) ? AdPad : DomainSep;
            curr  <= Perm;
          end else lane <= lane + 1;
        end

        AdPad: begin  // only S0 changes
          s[63:0]  <= s[63:0] ^ 64'd1;
          rnds     <= 8;
          after    <= DomainSep;
          curr     <= Perm;
        end

        DomainSep: begin
          s[319] <= ~s[319];
          curr   <= Data;
        end

        Data: begin  // ct lane and s lane in the same tick
          data_out_reg[64*lane+:64] <= ct[64*lane+:64];
          s[64*lane+:64] <= s[64*lane+:64] ^ data_blk[64*lane+:64];
          if (last) begin
            lane <= 0;
            if (data_len == 16) begin
              rnds  <= 8;
              after <= DataPad;
              curr  <= Perm;
            end else curr <= Final;
          end else lane <= lane + 1;
        end

        DataPad: begin  // no permutation, only S0 changes
          s[63:0]  <= s[63:0] ^ 64'd1;
          curr     <= Final;
        end

        Final: begin  // key into S2, S3
          s[128+64*lane+:64] <= s[128+64*lane+:64] ^ key[64*lane+:64];
          if (last) begin
            lane  <= 0;
            rnds  <= 12;
            after <= Tag;
            curr  <= Perm;
          end else lane <= lane + 1;
        end

        Tag: begin
          tag_out_reg[64*lane+:64] <= s[192+64*lane+:64] ^ key[64*lane+:64];
          if (last) begin  // compare on the second tick
            lane       <= 0;
            tag_ok_reg <= ((s[319:192] ^ key) == tag_in);
            busy_reg   <= 1'b0;
            done_reg   <= 1'b1;
            curr       <= Idle;
          end else lane <= lane + 1;
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
