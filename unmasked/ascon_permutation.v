module ascon_permutation (
    input  wire         clk,
    input  wire         rst,
    input  wire         load,
    input  wire [  3:0] rnds,
    input  wire [319:0] s_in,
    output wire [319:0] s_out,
    output wire         idle    // to signal when done
);

  reg  [319:0] s;  // state register
  reg  [  3:0] cnt;  // rounds left, 0 = idle
  wire [  3:0] rnd = -cnt;  // constant index = 16 - cnt

  wire [319:0] s_c;  // after constant addition
  wire [319:0] s_s;  // after substitution
  wire [319:0] s_l;  // after linear layer

  // add round constant
  ascon_addrndconst addrndconst (
      .s_in (s[191:128]),
      .rnd  (rnd),
      .s_out(s_c[191:128])
  );
  assign s_c[319:192] = s[319:192];
  assign s_c[127:0]   = s[127:0];

  // substitution
  ascon_substitution substitution (
      .s_in (s_c),
      .s_out(s_s)
  );

  // diffusion
  ascon_diffusion diffusion (
      .s_in (s_s),
      .s_out(s_l)
  );

  always @(posedge clk, posedge rst)
    if (rst) begin  // might be side-channel consideration
      s   <= 0;
      cnt <= 0;
    end else if (load) begin
      s   <= s_in;
      cnt <= rnds;
    end else if (cnt != 0) begin
      s   <= s_l;
      cnt <= cnt - 1;
    end

  assign idle  = (cnt == 0);
  assign s_out = s;

endmodule
