module mod_m_counter #(
    parameter integer N = 4,  // placeholders
    parameter integer M = 16
) (
    input  wire clk,
    input  wire rst,
    output wire max_tick
);

  reg [N:0] count;  // hold the count

  always @(posedge clk, posedge rst)
    if (rst) count <= 0;
    else count <= (count == (M - 1)) ? 0 : count + 1;

  assign max_tick = (count == (M - 1));

endmodule
