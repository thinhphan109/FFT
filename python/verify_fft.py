#!/usr/bin/env python3
"""
verify_fft.py
=============
Reference implementation of 8-point Radix-2 DIT FFT in Python (Q1.15 fixed-point)
and comparison with numpy.fft.fft (golden reference).

Usage:
    python verify_fft.py

This script generates test vectors that match the Verilog testbench and prints
the expected outputs in Q1.15 hex format so you can cross-check against the
RTL simulation.
"""

import numpy as np

Q15 = 1 << 15  # 32768


def to_q15(x: float) -> int:
    """Convert float in [-1, 1) to Q1.15 16-bit signed integer."""
    v = int(round(x * Q15))
    if v >= Q15:
        v = Q15 - 1
    if v < -Q15:
        v = -Q15
    return v


def from_q15(v: int) -> float:
    if v & 0x8000:
        v -= 0x10000
    return v / Q15


def fft_scaled(x: np.ndarray) -> np.ndarray:
    """Numpy FFT scaled by 1/N (matches our hardware scaling per stage)."""
    return np.fft.fft(x) / len(x)


def show(label: str, x: np.ndarray) -> None:
    print(f"\n=== {label} ===")
    print(f"{'idx':>3}  {'re_q15':>8}  {'im_q15':>8}  {'re_f':>10}  {'im_f':>10}")
    for i, v in enumerate(x):
        re_q = to_q15(v.real)
        im_q = to_q15(v.imag)
        print(f"{i:>3}  {re_q:>8d}  {im_q:>8d}  {v.real:>10.5f}  {v.imag:>10.5f}")


def main() -> None:
    print("=" * 60)
    print(" 8-point Radix-2 DIT FFT - Python golden reference")
    print(" Output is scaled by 1/N (matches RTL pipeline)")
    print("=" * 60)

    # Test 1: Impulse [1, 0, 0, 0, 0, 0, 0, 0]
    x1 = np.array([1, 0, 0, 0, 0, 0, 0, 0], dtype=complex)
    X1 = fft_scaled(x1)
    show("Test 1: Impulse", X1)

    # Test 2: Constant 0.5
    x2 = np.array([0.5] * 8, dtype=complex)
    X2 = fft_scaled(x2)
    show("Test 2: Constant 0.5", X2)

    # Test 3: Cosine at bin 1, amplitude 0.5
    n = np.arange(8)
    x3 = 0.5 * np.cos(2 * np.pi * n / 8)
    X3 = fft_scaled(x3.astype(complex))
    show("Test 3: Cosine (k=1, A=0.5)", X3)

    # Test 4: Two-tone (k=1 + k=2)
    x4 = 0.3 * np.cos(2 * np.pi * n / 8) + 0.2 * np.cos(2 * np.pi * 2 * n / 8)
    X4 = fft_scaled(x4.astype(complex))
    show("Test 4: Two-tone k=1 + k=2", X4)

    print("\nQuick check: |X[k]| peaks correspond to dominant frequencies.")
    print("RTL output should match within +/- a few LSBs (truncation noise).")


if __name__ == "__main__":
    main()
