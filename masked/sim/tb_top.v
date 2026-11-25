`timescale 1ns / 1ps

// whole top over uart: seed, key shares, official test vector, then
// encrypt 4 bytes and decrypt them back. needs stubs.v for the xilinx parts

module tb_top;

  reg clk = 0;
  always #20.833 clk = ~clk;  // 24 MHz, stub passes it straight through

  reg rst_btn = 1, nrst = 1, rx_pin = 1;
  wire tx_pin, trigger, clk_out;

  top dut (  // default 24 MHz, 115200 baud
      .clk    (clk),
      .rst_btn(rst_btn),
      .nrst   (nrst),
      .rx_pin (rx_pin),
      .tx_pin (tx_pin),
      .trigger(trigger),
      .clk_out(clk_out)
  );

  localparam integer Bit = 16 * 13;  // clk cycles per uart bit, 16 * BaudDiv

  // host -> fpga, 8N1
  task send(input [7:0] b);
    integer i;
    begin
      rx_pin = 0;
      repeat (Bit) @(posedge clk);
      for (i = 0; i < 8; i = i + 1) begin
        rx_pin = b[i];
        repeat (Bit) @(posedge clk);
      end
      rx_pin = 1;
      repeat (Bit) @(posedge clk);
    end
  endtask

  // fpga -> host, sample in the middle of each bit
  task recv(output [7:0] b);
    integer i;
    begin
      @(negedge tx_pin);
      repeat (Bit + Bit / 2) @(posedge clk);
      for (i = 0; i < 8; i = i + 1) begin
        b[i] = tx_pin;
        repeat (Bit) @(posedge clk);
      end
    end
  endtask

  reg [255:0] key_sh;
  reg [127:0] key, r, tag, ct, got_pt;
  reg [7:0] b, ok;
  integer i, seed = 3, fails = 0, cycles = 0;

  always @(posedge clk) if (trigger) cycles = cycles + 1;

  task send_key;
    begin
      r = {$random(seed), $random(seed), $random(seed), $random(seed)};
      key_sh = {r, key ^ r};
      send(8'h01);
      for (i = 0; i < 32; i = i + 1) send(key_sh[8*i+:8]);
    end
  endtask

  initial begin
    repeat (10) @(posedge clk);
    rst_btn = 0;
    repeat (10) @(posedge clk);

    // seed
    send(8'h07);
    for (i = 0; i < 40; i = i + 1) send($random(seed));

    $display("seed sent");

    // official test vector: key 00..0f, nonce 10..1f, no ad, no data
    for (i = 0; i < 16; i = i + 1) key[8*i+:8] = i;
    send_key;
    send(8'h02);
    for (i = 0; i < 16; i = i + 1) send(16 + i);
    send(8'h03);
    send(0);
    send(8'h04);
    send(0);
    send(8'h06);
    fork  // the reply can start before the stop bit is done, so listen now
      send(0);  // encrypt
      for (i = 0; i < 16; i = i + 1) begin
        recv(b);
        tag[8*i+:8] = b;
      end
    join
    $display("busy: %0d cycles (no ad, no data)", cycles);
    if (tag !== 128'hc62e8bee468ff66b31c9be1182279c4f) begin
      $display("FAIL test vector: tag %h", tag);
      fails = fails + 1;
    end

    // encrypt 4 bytes, new key shares for the same key
    send_key;
    send(8'h04);
    send(4);
    send(8'hde);
    send(8'had);
    send(8'hbe);
    send(8'hef);
    send(8'h06);
    ct = 0;
    fork
      send(0);  // encrypt
      for (i = 0; i < 20; i = i + 1) begin
        recv(b);
        if (i < 4) ct[8*i+:8] = b;
        else tag[8*(i-4)+:8] = b;
      end
    join

    // decrypt it back with the tag
    send(8'h04);
    send(4);
    for (i = 0; i < 4; i = i + 1) send(ct[8*i+:8]);
    send(8'h05);
    for (i = 0; i < 16; i = i + 1) send(tag[8*i+:8]);
    send(8'h06);
    got_pt = 0;
    fork
      send(1);  // decrypt
      begin
        recv(ok);
        for (i = 0; i < 4; i = i + 1) begin
          recv(b);
          got_pt[8*i+:8] = b;
        end
      end
    join
    if (ok !== 1 || got_pt !== 128'hefbeadde) begin
      $display("FAIL decrypt: tag_ok %0d, pt %h", ok, got_pt);
      fails = fails + 1;
    end

    $display("%0d fails", fails);
    $finish;
  end

endmodule
