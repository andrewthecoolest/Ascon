module ascon_substitution (
    input  wire         clk,
    input  wire         rst,
    input  wire         en,     // load the dom registers
    input  wire [319:0] z,      // fresh randomness, 64 bits per and
    input  wire [639:0] s_in,   // {share 1, share 0}
    output wire [639:0] s_out   // one cycle after en
);

  // input affine layer, linear so each share goes alone
  function [319:0] affine_in(input [319:0] s);
    begin
      affine_in = s;
      affine_in[63:0] = s[63:0] ^ s[319:256];  // x0 ^= x4
      affine_in[319:256] = s[319:256] ^ s[255:192];  // x4 ^= x3
      affine_in[191:128] = s[191:128] ^ s[127:64];  // x2 ^= x1
    end
  endfunction

  // output affine layer, the ~x2 is done on share 0 only
  function [319:0] affine_out(input [319:0] s);
    begin
      affine_out = s;
      affine_out[127:64] = s[127:64] ^ s[63:0];  // x1 ^= x0
      affine_out[63:0] = s[63:0] ^ s[319:256];  // x0 ^= x4
      affine_out[255:192] = s[255:192] ^ s[191:128];  // x3 ^= x2
    end
  endfunction

  wire [319:0] x_0 = affine_in(s_in[319:0]);
  wire [319:0] x_1 = affine_in(s_in[639:320]);

  // chi: x_i ^= ~x_{i+1} & x_{i+2}
  // t is the and part, the not is done on share 0 only
  wire [319:0] t_0, t_1;

  ascon_dom_and and_0 (
      .clk(clk),
      .rst(rst),
      .en (en),
      .a_0(~x_0[127:64]),
      .a_1(x_1[127:64]),
      .b_0(x_0[191:128]),
      .b_1(x_1[191:128]),
      .z  (z[63:0]),
      .q_0(t_0[63:0]),
      .q_1(t_1[63:0])
  );

  ascon_dom_and and_1 (
      .clk(clk),
      .rst(rst),
      .en (en),
      .a_0(~x_0[191:128]),
      .a_1(x_1[191:128]),
      .b_0(x_0[255:192]),
      .b_1(x_1[255:192]),
      .z  (z[127:64]),
      .q_0(t_0[127:64]),
      .q_1(t_1[127:64])
  );

  ascon_dom_and and_2 (
      .clk(clk),
      .rst(rst),
      .en (en),
      .a_0(~x_0[255:192]),
      .a_1(x_1[255:192]),
      .b_0(x_0[319:256]),
      .b_1(x_1[319:256]),
      .z  (z[191:128]),
      .q_0(t_0[191:128]),
      .q_1(t_1[191:128])
  );

  ascon_dom_and and_3 (
      .clk(clk),
      .rst(rst),
      .en (en),
      .a_0(~x_0[319:256]),
      .a_1(x_1[319:256]),
      .b_0(x_0[63:0]),
      .b_1(x_1[63:0]),
      .z  (z[255:192]),
      .q_0(t_0[255:192]),
      .q_1(t_1[255:192])
  );

  ascon_dom_and and_4 (
      .clk(clk),
      .rst(rst),
      .en (en),
      .a_0(~x_0[63:0]),
      .a_1(x_1[63:0]),
      .b_0(x_0[127:64]),
      .b_1(x_1[127:64]),
      .z  (z[319:256]),
      .q_0(t_0[319:256]),
      .q_1(t_1[319:256])
  );

  // register x too, so it lines up with t
  reg [639:0] x_r;

  always @(posedge clk, posedge rst)
    if (rst) x_r <= 0;
    else if (en) x_r <= {x_1, x_0};

  wire [319:0] y_0 = affine_out(x_r[319:0] ^ t_0);
  wire [319:0] y_1 = affine_out(x_r[639:320] ^ t_1);

  assign s_out[319:0]   = y_0 ^ {128'd0, ~64'd0, 128'd0};  // ~x2, share 0 only
  assign s_out[639:320] = y_1;


  /*

𝑦0 = 𝑥4𝑥1 ⊕ 𝑥3 ⊕ 𝑥2𝑥1 ⊕ 𝑥2 ⊕ 𝑥1𝑥0 ⊕ 𝑥1 ⊕ 𝑥0,
𝑦1 = 𝑥4 ⊕ 𝑥3𝑥2 ⊕ 𝑥3𝑥1 ⊕ 𝑥3 ⊕ 𝑥2𝑥1 ⊕ 𝑥2 ⊕ 𝑥1 ⊕ 𝑥0,
𝑦2 = 𝑥4𝑥3 ⊕ 𝑥4 ⊕ 𝑥2 ⊕ 𝑥1 ⊕ 1,
𝑦3 = 𝑥4𝑥0 ⊕ 𝑥4 ⊕ 𝑥3𝑥0 ⊕ 𝑥3 ⊕ 𝑥2 ⊕ 𝑥1 ⊕ 𝑥0,
𝑦4 = 𝑥4𝑥1 ⊕ 𝑥4 ⊕ 𝑥3 ⊕ 𝑥1𝑥0 ⊕ 𝑥1

same s-box as affine, chi, affine (5 ands instead of 8):

𝑥0 ⊕= 𝑥4, 𝑥4 ⊕= 𝑥3, 𝑥2 ⊕= 𝑥1
𝑥𝑖 ⊕= ¬𝑥𝑖+1 𝑥𝑖+2 (𝑖 = 0..4, indices mod 5)
𝑥1 ⊕= 𝑥0, 𝑥0 ⊕= 𝑥4, 𝑥3 ⊕= 𝑥2, 𝑥2 = ¬𝑥2

*/
endmodule
