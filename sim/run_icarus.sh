#!/bin/bash
# Run FFT-8 simulation with Icarus Verilog
# Requires: iverilog, vvp, gtkwave (optional)

set -e

cd "$(dirname "$0")/.."

echo "=== Compiling RTL + testbench ==="
iverilog -g2012 -o sim/fft8.vvp \
    rtl/complex_mul.v \
    rtl/butterfly.v \
    rtl/twiddle_rom.v \
    rtl/fft8_core.v \
    rtl/fft8_top.v \
    tb/tb_fft8.v

echo "=== Running simulation ==="
vvp sim/fft8.vvp

echo "=== Waveform saved to fft8.vcd ==="
echo "Open with: gtkwave fft8.vcd"
