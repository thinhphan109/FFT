# Đồ án: Thiết kế bộ tính toán FFT 8 điểm Radix-2 Decimation-In-Time bằng Verilog HDL

> **Môn học:** Thiết kế hệ thống vi mạch số  
> **Đề tài:** Thiết kế bộ FFT 8 điểm sử dụng kiến trúc Radix-2 DIT, fixed-point Q1.15  
> **Ngôn ngữ:** Verilog 2001 / SystemVerilog  
> **Mục tiêu điểm:** 9.0+

---

## 1. Giới thiệu

FFT (Fast Fourier Transform) là thuật toán tính rời rạc Fourier biến đổi (DFT) với độ phức tạp giảm từ `O(N²)` xuống `O(N·logN)`. Đây là khối quan trọng trong xử lý tín hiệu số, viễn thông (OFDM), nén ảnh/âm thanh, radar, và đo lường phổ.

Đồ án này thiết kế bộ FFT 8 điểm bằng **Verilog**, kiến trúc **Radix-2 Decimation-In-Time (DIT)**, dùng **số phức fixed-point Q1.15 (16-bit signed)**, mô phỏng bằng **Icarus Verilog/ModelSim** và đối chiếu với **NumPy** làm golden reference.

---

## 2. Cấu trúc thư mục

```
fft_project/
├── rtl/                    # Verilog RTL
│   ├── complex_mul.v       # Bộ nhân số phức Q1.15
│   ├── butterfly.v         # Đơn vị butterfly Radix-2 DIT
│   ├── twiddle_rom.v       # ROM hệ số xoay W8^k
│   ├── fft8_core.v         # Lõi FFT 3 stage
│   └── fft8_top.v          # Top wrapper có thanh ghi I/O
├── tb/
│   └── tb_fft8.v           # Testbench với 3 ca kiểm thử
├── sim/
│   ├── run_icarus.sh       # Script Icarus + GTKWave
│   └── run_modelsim.do     # Script ModelSim/Questa
├── python/
│   └── verify_fft.py       # Reference NumPy FFT
├── docs/
│   ├── report_outline.md   # Outline báo cáo 30 trang
│   ├── diagrams.md         # Sơ đồ khối + butterfly + signal flow
│   └── slide_bao_ve.html   # Slide bảo vệ HTML
├── .gitignore
└── README.md
```

---

## 3. Kiến trúc tổng quan

### 3.1 Sơ đồ khối top-level

```
                  +-------------------+
   x[0..7]  ----> |  Input Register   | -+
   valid_in ----> |   (clk, rst_n)    |  |
                  +-------------------+  |
                                         v
                  +-------------------------------+
                  |          fft8_core            |
                  |                               |
                  |  Bit-reversal                 |
                  |       |                       |
                  |       v                       |
                  |  Stage 1 (4 BF, W2^0)         |
                  |       |    [pipe reg]         |
                  |       v                       |
                  |  Stage 2 (4 BF, W4^{0,1})     |
                  |       |    [pipe reg]         |
                  |       v                       |
                  |  Stage 3 (4 BF, W8^{0..3})    |
                  |       |    [pipe reg]         |
                  +-------|-----------------------+
                          v
                  +-------------------+
                  | Output Register   | ---> X[0..7]
                  +-------------------+ ---> valid_out
```

- **Latency:** 5 chu kỳ (1 input reg + 3 stage + 1 output reg)
- **Throughput:** 1 phép biến đổi mỗi chu kỳ
- **Mỗi stage chia 1/2** để tránh tràn ⇒ output đã chia sẵn cho `N=8`

### 3.2 Định dạng số

**Q1.15** (16-bit signed): 1 bit dấu, 15 bit phân số ⇒ biểu diễn `[-1.0, +1.0)`

| Float |          Q1.15 |
| ----- | -------------: |
| +1.0  | 32767 (xấp xỉ) |
| +0.5  |          16384 |
| 0.0   |              0 |
| -0.5  |         -16384 |
| -1.0  |         -32768 |

**Quy tắc nhân:**

```
Q1.15 × Q1.15 = Q2.30 (32-bit)
→ truncate bằng cách lấy bits [30:15] để trả về Q1.15
```

### 3.3 Twiddle factors (W8^k = e^{-j·2πk/8})

| k   | Re (float) | Im (float) | Re (Q1.15) | Im (Q1.15) |
| --- | ---------: | ---------: | ---------: | ---------: |
| 0   |     1.0000 |     0.0000 |      32767 |          0 |
| 1   |     0.7071 |    -0.7071 |      23170 |     -23170 |
| 2   |     0.0000 |    -1.0000 |          0 |     -32768 |
| 3   |    -0.7071 |    -0.7071 |     -23170 |     -23170 |

### 3.4 Butterfly Radix-2 DIT

```
A ──────┬──── (A + B·W)/2 ──→ y0
        │
B ──[W]─┴──── (A − B·W)/2 ──→ y1
```

### 3.5 Sơ đồ luồng tín hiệu (8-point DIT)

```
n          stage1     stage2     stage3        k
0 ─────●───────●───────●─────────────────  0
       │       │       │
4 ──[W0]●     │       │
              │       │
2 ─────●──[W0]●       │              2
       │              │
6 ──[W0]●            │
                     │
1 ─────●───────●──[W0]●              1
       │       │
5 ──[W0]●     │
              │
3 ─────●──[W0]●                      3
       │
7 ──[W0]●

(Chi tiết đầy đủ: docs/diagrams.md)
```

---

## 4. Mô tả các module

### 4.1 `complex_mul.v`

Bộ nhân số phức `(a_re + j·a_im) × (b_re + j·b_im)` Q1.15.

### 4.2 `butterfly.v`

Đơn vị butterfly Radix-2 DIT với scale 1/2 ở đầu ra để tránh overflow.

### 4.3 `twiddle_rom.v`

ROM tổ hợp lưu 4 hệ số xoay W8^0..W8^3.

### 4.4 `fft8_core.v`

Lõi FFT 3 stage với 12 butterfly và 3 thanh ghi pipeline.

### 4.5 `fft8_top.v`

Wrapper có thanh ghi đầu vào/đầu ra để đóng gói cho synthesis.

---

## 5. Chạy mô phỏng

### 5.1 Icarus Verilog (Linux/macOS/WSL/Git Bash)

```bash
cd fft_project
bash sim/run_icarus.sh
gtkwave fft8.vcd
```

### 5.2 Icarus trên Windows PowerShell

```powershell
cd fft_project
iverilog -g2012 -o sim/fft8.vvp `
    rtl/complex_mul.v rtl/butterfly.v rtl/twiddle_rom.v `
    rtl/fft8_core.v rtl/fft8_top.v tb/tb_fft8.v
vvp sim/fft8.vvp
```

### 5.3 ModelSim/Questa

```tcl
cd sim
vsim -do run_modelsim.do
```

### 5.4 Python golden reference

```bash
cd python
python verify_fft.py
```

---

## 6. Test cases

| Test   | Input                        | Expected Output                  |
| ------ | ---------------------------- | -------------------------------- |
| 1      | Impulse `[1,0,0,0,0,0,0,0]`  | `X[k] = 1/8` cho mọi k (≈ 4095)  |
| 2      | Constant `[0.5,0.5,...,0.5]` | `X[0] = 0.5` (≈ 16384), khác = 0 |
| 3      | Cosine bin 1, A=0.5          | Peak ở bin 1 và bin 7            |
| 4 (PY) | Two-tone k=1 + k=2           | Peak ở bin 1, 2, 6, 7            |

Sai số chấp nhận: **±32 LSB** (do truncation Q1.15).

---

## 7. Tài nguyên dự kiến (Synthesis)

| Resource                |                                      Estimate |
| ----------------------- | --------------------------------------------: |
| 16×16 multipliers       | 12 (1 mỗi butterfly × 12 BF) → có thể chia sẻ |
| Slice LUT               |                                         ~1500 |
| Slice FF                |                                          ~800 |
| f_max (Xilinx 7-series) |                                      ~150 MHz |

---

## 8. Roadmap mở rộng

- FFT 16/32/64-point (thêm stage)
- Pipeline streaming với AXI4-Stream
- Cấu hình động Radix-4
- Floating-point FP32 (sử dụng Xilinx FP IP)
- IFFT (đảo dấu phần ảo của twiddle)

---

## 9. Tài liệu tham khảo

1. Cooley & Tukey (1965). _An Algorithm for the Machine Calculation of Complex Fourier Series._
2. Oppenheim & Schafer. _Discrete-Time Signal Processing_, Chapter 9.
3. Xilinx UG901 - Vivado Synthesis.
4. Saleh, Habib F. _Fixed-Point FFT Architectures_, IEEE.

---

## 10. Tác giả

- Nhóm: <điền tên nhóm>
- Trường/Khoa: <điền>
- Mã môn học: <điền>
- Năm học: 2025–2026
