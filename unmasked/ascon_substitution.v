module ascon_substitution (
    input  wire [319:0] s_in,
    output wire [319:0] s_out
);

  wire [63:0] s_0 = s_in[63:0];
  wire [63:0] s_1 = s_in[127:64];
  wire [63:0] s_2 = s_in[191:128];
  wire [63:0] s_3 = s_in[255:192];
  wire [63:0] s_4 = s_in[319:256];

  assign s_out[63:0] = s_4 & s_1 ^ s_3 ^ s_2 & s_1 ^ s_2 ^ s_1 & s_0 ^ s_1 ^ s_0;
  assign s_out[127:64] = s_4 ^ s_3 & s_2 ^ s_3 & s_1 ^ s_3 ^ s_2 & s_1 ^ s_2 ^ s_1 ^ s_0;
  assign s_out[191:128] = ~(s_4 & s_3 ^ s_4 ^ s_2 ^ s_1);
  assign s_out[255:192] = s_4 & s_0 ^ s_4 ^ s_3 & s_0 ^ s_3 ^ s_2 ^ s_1 ^ s_0;
  assign s_out[319:256] = s_4 & s_1 ^ s_4 ^ s_3 ^ s_1 & s_0 ^ s_1;


  /*

𝑦0 = 𝑥4𝑥1 ⊕ 𝑥3 ⊕ 𝑥2𝑥1 ⊕ 𝑥2 ⊕ 𝑥1𝑥0 ⊕ 𝑥1 ⊕ 𝑥0,
𝑦1 = 𝑥4 ⊕ 𝑥3𝑥2 ⊕ 𝑥3𝑥1 ⊕ 𝑥3 ⊕ 𝑥2𝑥1 ⊕ 𝑥2 ⊕ 𝑥1 ⊕ 𝑥0,
𝑦2 = 𝑥4𝑥3 ⊕ 𝑥4 ⊕ 𝑥2 ⊕ 𝑥1 ⊕ 1,
𝑦3 = 𝑥4𝑥0 ⊕ 𝑥4 ⊕ 𝑥3𝑥0 ⊕ 𝑥3 ⊕ 𝑥2 ⊕ 𝑥1 ⊕ 𝑥0,
𝑦4 = 𝑥4𝑥1 ⊕ 𝑥4 ⊕ 𝑥3 ⊕ 𝑥1𝑥0 ⊕ 𝑥1

*/
endmodule
