#!/bin/sh
# simulate with iverilog, run from serial/sim
set -e

# serial core vs unmasked core, same random vectors
iverilog -g2005 -o serial.vvp tb_aead.v ../ascon_*.v
iverilog -g2005 -DUNMASKED -o unmasked.vvp tb_aead.v ../../unmasked/ascon_*.v
vvp -n serial.vvp
vvp -n unmasked.vvp
cmp serial.txt unmasked.txt && echo "serial == unmasked"

# whole top over uart
iverilog -g2005 -o top.vvp tb_top.v stubs.v ../top.v ../host_if.v \
  ../ascon_*.v ../uart_rx.v ../uart_tx.v ../mod_m_counter.v
vvp -n top.vvp
