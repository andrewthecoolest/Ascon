#!/bin/sh
# simulate with iverilog, run from masked/sim
set -e

# masked core vs unmasked core, same random vectors
iverilog -g2005 -o masked.vvp tb_aead.v ../ascon_*.v ../prng.v
iverilog -g2005 -DUNMASKED -o unmasked.vvp tb_aead.v ../../unmasked/ascon_*.v
vvp -n masked.vvp
vvp -n unmasked.vvp
cmp masked.txt unmasked.txt && echo "masked == unmasked"

# whole top over uart
iverilog -g2005 -o top.vvp tb_top.v stubs.v ../top.v ../host_if.v ../prng.v \
  ../ascon_*.v ../uart_rx.v ../uart_tx.v ../mod_m_counter.v
vvp -n top.vvp
