module ascon_addrndconst (
    input  wire [63:0] s_in,
    input  wire [ 3:0] rnd,
    output wire [63:0] s_out
);

  assign s_out = s_in ^ {56'd0, 4'h3 - rnd, 4'hc + rnd};

endmodule
