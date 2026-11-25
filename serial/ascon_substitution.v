module ascon_substitution (
    input  wire [4:0] s_in,  // one column: bit i of S0..S4
    output wire [4:0] s_out
);

  wire s_0 = s_in[0];
  wire s_1 = s_in[1];
  wire s_2 = s_in[2];
  wire s_3 = s_in[3];
  wire s_4 = s_in[4];

  assign s_out[0] = s_4 & s_1 ^ s_3 ^ s_2 & s_1 ^ s_2 ^ s_1 & s_0 ^ s_1 ^ s_0;
  assign s_out[1] = s_4 ^ s_3 & s_2 ^ s_3 & s_1 ^ s_3 ^ s_2 & s_1 ^ s_2 ^ s_1 ^ s_0;
  assign s_out[2] = ~(s_4 & s_3 ^ s_4 ^ s_2 ^ s_1);
  assign s_out[3] = s_4 & s_0 ^ s_4 ^ s_3 & s_0 ^ s_3 ^ s_2 ^ s_1 ^ s_0;
  assign s_out[4] = s_4 & s_1 ^ s_4 ^ s_3 ^ s_1 & s_0 ^ s_1;


  /*

𝑦0 = 𝑥4𝑥1 ⊕ 𝑥3 ⊕ 𝑥2𝑥1 ⊕ 𝑥2 ⊕ 𝑥1𝑥0 ⊕ 𝑥1 ⊕ 𝑥0,
𝑦1 = 𝑥4 ⊕ 𝑥3𝑥2 ⊕ 𝑥3𝑥1 ⊕ 𝑥3 ⊕ 𝑥2𝑥1 ⊕ 𝑥2 ⊕ 𝑥1 ⊕ 𝑥0,
𝑦2 = 𝑥4𝑥3 ⊕ 𝑥4 ⊕ 𝑥2 ⊕ 𝑥1 ⊕ 1,
𝑦3 = 𝑥4𝑥0 ⊕ 𝑥4 ⊕ 𝑥3𝑥0 ⊕ 𝑥3 ⊕ 𝑥2 ⊕ 𝑥1 ⊕ 𝑥0,
𝑦4 = 𝑥4𝑥1 ⊕ 𝑥4 ⊕ 𝑥3 ⊕ 𝑥1𝑥0 ⊕ 𝑥1

*/
endmodule
