module ascon_permutation (
    input  wire         clk,
    input  wire         rst,
    input  wire         load,
    input  wire [  3:0] rnds,
    input  wire [319:0] z,      // fresh randomness for the s-box
    input  wire [639:0] s_in,   // {share 1, share 0}
    output wire [639:0] s_out,
    output wire         idle    // to signal when done
);

  reg  [639:0] s;  // state register, 2 shares
  reg  [  3:0] cnt;  // rounds left, 0 = idle
  reg          half;  // 0 = fill dom registers, 1 = update s
  wire [  3:0] rnd = -cnt;  // constant index = 16 - cnt

  wire [639:0] s_c;  // after constant addition
  wire [639:0] s_s;  // after substitution, registered
  wire [639:0] s_l;  // after linear layer

  // add round constant, share 0 only
  ascon_addrndconst addrndconst (
      .s_in (s[191:128]),
      .rnd  (rnd),
      .s_out(s_c[191:128])
  );
  assign s_c[639:192] = s[639:192];
  assign s_c[127:0]   = s[127:0];

  // substitution, dom registers load in the first half of a round
  ascon_substitution substitution (
      .clk  (clk),
      .rst  (rst),
      .en   ((cnt != 0) & ~half),
      .z    (z),
      .s_in (s_c),
      .s_out(s_s)
  );

  // diffusion, linear so each share goes alone
  ascon_diffusion diffusion_0 (
      .s_in (s_s[319:0]),
      .s_out(s_l[319:0])
  );

  ascon_diffusion diffusion_1 (
      .s_in (s_s[639:320]),
      .s_out(s_l[639:320])
  );

  // two cycles per round
  always @(posedge clk, posedge rst)
    if (rst) begin  // might be side-channel consideration
      s    <= 0;
      cnt  <= 0;
      half <= 0;
    end else if (load) begin
      s    <= s_in;
      cnt  <= rnds;
      half <= 0;
    end else if (cnt != 0) begin
      if (half) begin
        s   <= s_l;
        cnt <= cnt - 1;
      end
      half <= ~half;
    end

  assign idle  = (cnt == 0);
  assign s_out = s;

endmodule
