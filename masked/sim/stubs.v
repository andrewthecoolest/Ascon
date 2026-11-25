// sim-only stand-ins for the xilinx parts in top.v

module clk_wiz_0 (
    input  wire clk_in1,
    output wire clk_out1,
    output wire locked
);
  assign clk_out1 = clk_in1;  // tb already runs at 24 MHz
  assign locked   = 1'b1;
endmodule

module ODDR #(
    parameter DDR_CLK_EDGE = "SAME_EDGE"
) (
    output wire Q,
    input  wire C,
    input  wire CE,
    input  wire D1,
    input  wire D2,
    input  wire R,
    input  wire S
);
  assign Q = C ? D1 : D2;
endmodule
