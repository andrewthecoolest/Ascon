module prng (
    input  wire         clk,
    input  wire         rst,
    input  wire         load,  // one-cycle pulse: s <= seed
    input  wire [319:0] seed,  // no lane may be all zero
    output wire [319:0] z      // fresh randomness, new every cycle
);

  // 5 lanes of xorshift64, every lane steps once per cycle
  // not a cryptographic prng, just cheap random bits for the masks
  // the step is invertible, so the 320 bits in one cycle are independent

  reg [319:0] s;

  function [63:0] xorshift(input [63:0] x);
    reg [63:0] t;
    begin
      t = x ^ (x << 13);
      t = t ^ (t >> 7);
      xorshift = t ^ (t << 17);
    end
  endfunction

  wire [319:0] s_next;

  genvar i;
  generate
    for (i = 0; i < 5; i = i + 1) begin : lane
      assign s_next[64*i+:64] = xorshift(s[64*i+:64]);
    end
  endgenerate

  always @(posedge clk, posedge rst)
    if (rst) s <= {5{64'h9e3779b97f4a7c15}};  // weak until the host sends a seed
    else if (load) s <= seed;
    else s <= s_next;

  assign z = s;

endmodule
