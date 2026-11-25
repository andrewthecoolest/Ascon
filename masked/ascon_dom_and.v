module ascon_dom_and (
    input  wire        clk,
    input  wire        rst,
    input  wire        en,   // load the product registers
    input  wire [63:0] a_0,
    input  wire [63:0] a_1,
    input  wire [63:0] b_0,
    input  wire [63:0] b_1,
    input  wire [63:0] z,    // fresh randomness, 1 bit per AND
    output wire [63:0] q_0,
    output wire [63:0] q_1
);

  // products, p_ij = a_i & b_j
  // cross products (i != j) are masked before the register
  reg [63:0] p_00, p_01;
  reg [63:0] p_10, p_11;

  always @(posedge clk, posedge rst)
    if (rst) begin
      p_00 <= 0;
      p_01 <= 0;
      p_10 <= 0;
      p_11 <= 0;
    end else if (en) begin
      p_00 <= a_0 & b_0;
      p_01 <= a_0 & b_1 ^ z;
      p_10 <= a_1 & b_0 ^ z;
      p_11 <= a_1 & b_1;
    end

  // compress, each output share only uses its own registers
  assign q_0 = p_00 ^ p_01;
  assign q_1 = p_10 ^ p_11;

  /*

DOM-indep AND, 2 shares (Gross et al. 2016)

𝑞0 = 𝑎0𝑏0 ⊕ (𝑎0𝑏1 ⊕ 𝑧)
𝑞1 = (𝑎1𝑏0 ⊕ 𝑧) ⊕ 𝑎1𝑏1

𝑞0 ⊕ 𝑞1 = (𝑎0 ⊕ 𝑎1)(𝑏0 ⊕ 𝑏1)

*/
endmodule
