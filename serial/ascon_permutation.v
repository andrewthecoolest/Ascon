module ascon_permutation (
    input  wire         clk,
    input  wire         rst,
    input  wire         load,
    input  wire [  3:0] rnds,
    input  wire [319:0] s_in,   // must hold still while lanes load
    output wire [319:0] s_out,
    output wire         idle    // to signal when done
);

  // one thing per tick. after load: 5 ticks to copy s_in, one lane each.
  // then each round is 70 ticks:
  //   step 0      add round constant
  //   step 1-64   sbox on column step-1 (bit i of every lane)
  //   step 65-69  diffusion on lane step-65

  reg  [319:0] s;  // state register
  reg  [  3:0] cnt;  // rounds left, 0 = idle
  reg  [  6:0] step;  // tick inside the round, 0-69
  reg  [  2:0] ld;  // lanes left to copy in, 0 = loaded
  wire [  3:0] rnd = -cnt;  // constant index = 16 - cnt

  wire [  2:0] ld_lane = 3'd5 - ld;  // lane copied this tick
  wire [  5:0] col = step - 7'd1;  // sbox column this tick
  wire [  2:0] dlane = step - 7'd65;  // diffusion lane this tick

  wire [ 63:0] s_c;  // S2 after constant addition
  wire [  4:0] s_s;  // column after substitution
  wire [ 63:0] s_l;  // lane after linear layer

  // add round constant
  ascon_addrndconst addrndconst (
      .s_in (s[191:128]),
      .rnd  (rnd),
      .s_out(s_c)
  );

  // substitution
  ascon_substitution substitution (
      .s_in ({s[256+col], s[192+col], s[128+col], s[64+col], s[col]}),
      .s_out(s_s)
  );

  // diffusion
  ascon_diffusion diffusion (
      .s_in (s[64*dlane+:64]),
      .lane (dlane),
      .s_out(s_l)
  );

  always @(posedge clk, posedge rst)
    if (rst) begin  // might be side-channel consideration
      s    <= 0;
      cnt  <= 0;
      step <= 0;
      ld   <= 0;
    end else if (load) begin
      cnt  <= rnds;
      step <= 0;
      ld   <= 5;
    end else if (ld != 0) begin  // copy one lane
      s[64*ld_lane+:64] <= s_in[64*ld_lane+:64];
      ld <= ld - 1;
    end else if (cnt != 0) begin
      if (step == 0) s[191:128] <= s_c;
      else if (step <= 64) begin
        s[col]     <= s_s[0];
        s[64+col]  <= s_s[1];
        s[128+col] <= s_s[2];
        s[192+col] <= s_s[3];
        s[256+col] <= s_s[4];
      end else s[64*dlane+:64] <= s_l;

      if (step == 69) begin  // round done
        step <= 0;
        cnt  <= cnt - 1;
      end else step <= step + 1;
    end

  assign idle  = (cnt == 0) && (ld == 0);
  assign s_out = s;

endmodule
