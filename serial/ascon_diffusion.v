module ascon_diffusion (
  input wire [63:0] s_in,  // one lane
  input wire [2:0] lane,  // which lane it is, 0-4
  output wire [63:0] s_out
);

  wire [63:0] l_0 = s_in ^ {s_in[18:0], s_in[63:19]} ^ {s_in[27:0], s_in[63:28]};
  wire [63:0] l_1 = s_in ^ {s_in[60:0], s_in[63:61]} ^ {s_in[38:0], s_in[63:39]};
  wire [63:0] l_2 = s_in ^ {s_in[0], s_in[63:1]} ^ {s_in[5:0], s_in[63:6]};
  wire [63:0] l_3 = s_in ^ {s_in[9:0], s_in[63:10]} ^ {s_in[16:0], s_in[63:17]};
  wire [63:0] l_4 = s_in ^ {s_in[6:0], s_in[63:7]} ^ {s_in[40:0], s_in[63:41]};

  assign s_out = (lane == 3'd0) ? l_0 :
                 (lane == 3'd1) ? l_1 :
                 (lane == 3'd2) ? l_2 :
                 (lane == 3'd3) ? l_3 : l_4;

/*

Σ0(𝑆0) = 𝑆0 ⊕ (𝑆0 ⋙ 19) ⊕ (𝑆0 ⋙ 28) (8)
Σ1(𝑆1) = 𝑆1 ⊕ (𝑆1 ⋙ 61) ⊕ (𝑆1 ⋙ 39) (9)
Σ2(𝑆2) = 𝑆2 ⊕ (𝑆2 ⋙ 1) ⊕ (𝑆2 ⋙ 6) (10)
Σ3(𝑆3) = 𝑆3 ⊕ (𝑆3 ⋙ 10) ⊕ (𝑆3 ⋙ 17) (11)
Σ4(𝑆4) = 𝑆4 ⊕ (𝑆4 ⋙ 7) ⊕ (𝑆4 ⋙ 41) (12)

 * */

endmodule
