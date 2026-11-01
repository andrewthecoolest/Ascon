module ascon_aead128 (
    input wire clk,
    input wire rst,
    input wire mode  // Encrypt or Decrypt
);

  // state declaration
  localparam integer Initialization = 0, AssociatedData = 1, Processing = 2, Finalization = 3;

  // mode declaration
  localparam integer Encrypt = 0, Decrypt = 1;

  reg [1:0] curr;  // state of FSM

  // ascon state
  reg [319:0] s;
  wire [319:0] s_w;  // working state

  // permutation signals
  wire load;
  wire idle;

  // TODO: need some module for I/O:
  //
  // input:
  // mode
  // plaintext / decryption file ( {nonce , ciphertext, tag} )
  // key
  // associated data
  //
  // output:
  // .dec file for decrypted
  // .enc file for encrypted
  // error out if tag mismatch

  /*

  module ascon_permutation (
    input  wire         clk,
    input  wire         rst,
    input  wire         load,
    input  wire [  3:0] rnds,
    input  wire [319:0] s_in,
    output wire [319:0] s_out,
    output wire         idle    // to signal when done
  );

  */

  ascon_permutation permutation ();

  always @(posedge clk, posedge rst)
    if (rst) begin
      curr <= Initialization;
      s <= 320'd0;
      // zero every on initialization
    end else begin
      if (curr == Initialization) begin
        // load data into state
        // permutation 12 times
        // key XOR into s4
        curr <= AssociatedData;
      end else if (curr == AssociatedData) begin
        // while n != m
        //  An XOR s[127:0]
        //  permutation 8 times
        //  n++
        // 1 XOR
        curr <= Processing;
      end else if (curr == Processing) begin
        if (mode == Encrypt) begin
          // while n != m
          //  s[127:0] = Pn XOR s[127:0]
          //  Cn = s[127:0] -> out somehow
          //  permutation 8 times
          //  n++
        end else begin
          // while n != m
          //  Pn = Cn XOR s[127:0]
          //  Pn -> out somehow
          //  s[127:0] = Cn
          //  permutation 8 times
          //  n++
        end
      end else if (curr == Finalization) begin
        // key XOR
        // permute 12 times
        // key XOR again
        if (mode == Encrypt) begin
          // create tag
        end else begin
          // check tag
        end
      end
      // work through the states on clock tick
    end

endmodule
