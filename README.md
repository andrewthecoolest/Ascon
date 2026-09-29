# Characterizing Share Recombination in a Masked Ascon Implementation on Artix-7

CSCI-4041 Final Project, Andrew Loera

## Problem and Motivation

Side-channel attacks matter most where an attacker physically holds the device under attack. This is common for resource-constrained devices. In 2025, Ascon [1], a lightweight family of cryptographic functions, was standardized by NIST in SP 800-232 [2] for resource-constrained devices. Even though Ascon is cryptographically sound, its implementation in hardware is not guaranteed to be side-channel resistant. Two standard countermeasures exist: hiding and masking [3].

Masking splits secret-dependent data into random shares. Its security relies on the assumption that each share will leak independently. However, the tools used to turn abstract logic into implemented gates may break this assumption. Optimizations that combine logic, reduce redundant registers, and retime logic across register boundaries can recombine the random shares and reintroduce first-order leakage even if the RTL is provably secure. This project follows a masked Ascon design from the RTL down to its implementation on an Artix-7. It measures which optimizations break masking and whether breakage can be predicted from the netlist alone.

## Research Questions

- **RQ1:** Does default synthesis reintroduce leakage into masked Ascon?
- **RQ2:** Which specific optimizations reduce the security of masked Ascon?
- **RQ3:** Can leakage be predicted given a netlist?

## Security Goal

Protect the 128-bit secret key of an Ascon-AEAD128 hardware core. The goal of masking is first-order side-channel security: an attacker should not be able to extract information about the key in 10⁶ traces with power or EM analysis. Masking is well implemented if no sample point exceeds |t| > 4.5 in two independent fixed-vs-random TVLA trace sets [4] and first-order power or EM analysis fails to recover the key within 10⁶ traces.

## Threat Model

- The attacker knows the algorithm (Ascon-AEAD128) and the full netlist.
- One secret key is fixed for the whole experiment.
- The attacker knows every nonce and can choose it.
- Power is measured through a shunt resistor with a ChipWhisperer Lite, at a budget of 10⁶ traces.
- EM emissions are measured through a near-field H-field scanner, at a budget of 10⁶ traces.
- The attacker performs univariate first-order analysis (TVLA [4], CPA).
- Fault injection, higher-order attacks, and attacks on the TRNG are out of scope.

## Approach

1. **Unmasked baseline:** Test unmasked Ascon with TVLA and attack it with CPA, using power and EM.
2. **Hardened masked baseline:** Synthesize masked Ascon with settings that keep shares separate. This is the reference for correct masking.
3. **Masks-off control:** Run the hardened design with masking randomness disabled. It must leak.
4. **Default synthesis:** Synthesize the same masked design with default Vivado settings, test for leakage, and attack if leakage is found. (RQ1)
5. **Optimization sweep:** Enable optimizations one at a time and test each configuration with power analysis. (RQ2)
6. **Netlist analysis:** Flag LUTs in each netlist that combine both shares of a variable and compare the flags against the leakage results. (RQ3)
7. **EM leakage mapping:** For flagged configurations, map where leakage occurs on the die and compare it to where the flagged LUTs are placed. (RQ3)

## Experiment Setup

- **Target:** Basys 3 (Artix-7), modified with a shunt resistor for power analysis.
- **EM:** Custom EM scanner. A coarse scan finds compute hot spots, then the full trace budget is spent at candidate positions.
- **Capture:** ChipWhisperer Lite, using the FPGA's clock for coherent sampling.
- **Randomness:** PRNG seeded by a ring-oscillator TRNG.
- **Leakage criterion:** |t| > 4.5 at the same points in two independent sets of 10⁶ traces.
- **Automation:** A script synthesizes, runs the static netlist analysis, programs the FPGA, and captures traces for each optimization configuration.

## Expected Results

- **ER1:** Synthesis optimizations will reintroduce leakage, but key recovery will require more traces than the unmasked baseline.
- **ER2:** LUT merging will reduce the security masking provides.
- **ER3:** Netlist analysis will predict most leakage but miss effects from physical routing.

## References

1. Dobraunig, C., Eichlseder, M., Mendel, F., Schläffer, M. "Ascon v1.2: Lightweight Authenticated Encryption and Hashing." *Journal of Cryptology* 34(3), 2021. DOI: 10.1007/s00145-021-09398-9
2. Turan, M.S., McKay, K., Kang, J., Kelsey, J., Chang, D. "Ascon-Based Lightweight Cryptography Standards for Constrained Devices: Authenticated Encryption, Hash, and Extendable Output Functions." NIST SP 800-232, August 13, 2025. DOI: 10.6028/NIST.SP.800-232
3. Mangard, S., Oswald, E., Popp, T. *Power Analysis Attacks: Revealing the Secrets of Smart Cards.* Springer, 2007.
4. Goodwill, G., Jun, B., Jaffe, J., Rohatgi, P. "A Testing Methodology for Side-Channel Resistance Validation." NIST Non-Invasive Attack Testing Workshop (NIAT), Nara, Japan, September 2011.
