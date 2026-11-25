`timescale 1ns / 1ps

// runs the official test vector, then every ad and data length (0-16) with
// random inputs. each vector: encrypt, decrypt, decrypt with a bad tag.
// results go to a file. build once serial, once with -DUNMASKED against the
// unmasked sources, and the two files must match. see run.sh

module tb_aead;

  reg clk = 0, rst = 1;
  always #5 clk = ~clk;

  reg [127:0] key, nonce, ad, data_in, tag_in;
  reg [4:0] ad_len, data_len;
  reg mode, start;
  wire [127:0] data_out, tag_out;
  wire busy, done, tag_ok;

  ascon_aead128 dut (
      .clk     (clk),
      .rst     (rst),
      .key     (key),
      .nonce   (nonce),
      .ad      (ad),
      .ad_len  (ad_len),
      .data_in (data_in),
      .data_len(data_len),
      .tag_in  (tag_in),
      .mode    (mode),
      .start   (start),
      .data_out(data_out),
      .tag_out (tag_out),
      .busy    (busy),
      .done    (done),
      .tag_ok  (tag_ok)
  );

  integer vseed = 1;  // inputs, same in both builds
  integer f, i, a, d, cycles, fails;

  // 128 random bits from seed variable sd
`define rand128(sd) {$random(sd), $random(sd), $random(sd), $random(sd)}

  // run the core once, count the cycles busy is high
  task run(input m);
    begin
      mode = m;
      @(negedge clk) start = 1;
      @(negedge clk) start = 0;
      cycles = 1;
      while (!done) begin
        @(negedge clk) cycles = cycles + 1;
      end
    end
  endtask

  reg [127:0] mask, ct, tag, pt;

  initial begin
    start = 0;
    tag_in = 0;
    repeat (3) @(negedge clk);
    rst = 0;

`ifdef UNMASKED
    f = $fopen("unmasked.txt", "w");
`else
    f = $fopen("serial.txt", "w");
`endif
    fails = 0;

    // official test vector: key 00..0f, nonce 10..1f, no ad, no data
    for (i = 0; i < 16; i = i + 1) begin
      key[8*i+:8]   = i;
      nonce[8*i+:8] = 16 + i;
    end
    ad = 0;
    ad_len = 0;
    data_in = 0;
    data_len = 0;
    run(0);
    $display("busy: %0d cycles (no ad, no data)", cycles);
    if (tag_out !== 128'hc62e8bee468ff66b31c9be1182279c4f) begin  // bytes are little endian
      $display("FAIL test vector: tag %h", tag_out);
      fails = fails + 1;
    end

    for (a = 0; a <= 16; a = a + 1)
    for (d = 0; d <= 16; d = d + 1) begin
      key = `rand128(vseed);
      nonce = `rand128(vseed);
      ad = `rand128(vseed);
      data_in = `rand128(vseed);
      ad_len = a;
      data_len = d;
      mask = ~({128{1'b1}} << (8 * d));
      pt = data_in & mask;

      run(0);  // encrypt
      ct = data_out;
      tag = tag_out;
      $fdisplay(f, "a=%0d d=%0d enc %h %h", a, d, ct, tag);

      data_in = ct;
      tag_in = tag;
      run(1);  // decrypt, right tag
      $fdisplay(f, "a=%0d d=%0d dec %h %h %b", a, d, data_out, tag_out, tag_ok);
      if (data_out !== pt || tag_ok !== 1) begin
        $display("FAIL decrypt a=%0d d=%0d", a, d);
        fails = fails + 1;
      end

      tag_in = tag ^ 1;
      run(1);  // decrypt, bad tag
      $fdisplay(f, "a=%0d d=%0d bad %b", a, d, tag_ok);
      if (tag_ok !== 0) begin
        $display("FAIL bad tag accepted a=%0d d=%0d", a, d);
        fails = fails + 1;
      end
    end

    $fclose(f);
    $display("%0d fails", fails);
    $finish;
  end

endmodule
