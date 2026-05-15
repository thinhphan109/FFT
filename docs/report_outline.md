# Outline báo cáo đồ án — FFT 8-point Radix-2

> Tổng số trang dự kiến: **30 trang** (không kể bìa và phụ lục)
> Font: Times New Roman 13, line spacing 1.5, lề 2.5 cm

---

## Trang bìa + Bìa phụ (2 trang)

- Tên trường, khoa, bộ môn
- Tên đồ án: **Thiết kế bộ tính toán FFT 8 điểm Radix-2 DIT bằng Verilog HDL**
- GVHD: ****\_\_\_\_****
- SVTH: ****\_\_\_\_****
- Năm học: 2025–2026

---

## Mục lục, Danh mục hình, Danh mục bảng (3 trang)

---

## CHƯƠNG 1 — TỔNG QUAN ĐỀ TÀI (3 trang)

### 1.1 Đặt vấn đề

Tầm quan trọng của FFT trong xử lý tín hiệu, viễn thông, OFDM, radar.

### 1.2 Mục tiêu đồ án

- Thiết kế lõi FFT 8 điểm trên Verilog
- Mô phỏng và xác minh bằng testbench
- So sánh với Python NumPy
- Đánh giá tài nguyên synthesis

### 1.3 Phạm vi

- N = 8
- Fixed-point Q1.15
- Kiến trúc Radix-2 DIT parallel
- Không bao gồm IFFT (đề xuất phần roadmap)

### 1.4 Phương pháp nghiên cứu

- Lý thuyết DFT/FFT
- Thiết kế RTL theo top-down
- Verification bằng directed test

---

## CHƯƠNG 2 — CƠ SỞ LÝ THUYẾT (6 trang)

### 2.1 DFT — Discrete Fourier Transform

Công thức DFT, độ phức tạp O(N²).

### 2.2 Thuật toán FFT

- Cooley–Tukey 1965
- Radix-2 Decimation-In-Time (DIT)
- Radix-2 Decimation-In-Frequency (DIF)
- So sánh DIT và DIF

### 2.3 Twiddle factor

- Định nghĩa W_N^k = e^{−j·2πk/N}
- Tính chu kỳ và đối xứng
- Bảng W8^k cho N = 8

### 2.4 Butterfly Radix-2

- Phương trình butterfly
- Sơ đồ
- Bit-reversal ordering

### 2.5 Số học fixed-point Q1.15

- Format Q1.15 (16-bit)
- Phép cộng/trừ và bit growth
- Phép nhân Q1.15 × Q1.15 = Q2.30
- Truncation/rounding
- Quản lý overflow

---

## CHƯƠNG 3 — THIẾT KẾ HỆ THỐNG (8 trang)

### 3.1 Kiến trúc tổng thể

Block diagram top-level (xem `diagrams.md`).

### 3.2 Mô tả các module RTL

#### 3.2.1 `complex_mul.v`

- Chức năng
- Thuật toán
- Sơ đồ
- Code mô tả

#### 3.2.2 `butterfly.v`

- Sơ đồ Radix-2 DIT
- Scaling 1/2 mỗi stage
- Code

#### 3.2.3 `twiddle_rom.v`

- Bảng tra
- Lý do chọn ROM tổ hợp

#### 3.2.4 `fft8_core.v`

- 3 stage pipelined
- Bit-reversal hard-wired
- Phân bố twiddle factors

#### 3.2.5 `fft8_top.v`

- Thanh ghi I/O cho synthesis
- Latency tổng

### 3.3 Sơ đồ luồng tín hiệu (Signal Flow Graph)

Hình SFG 8-point DIT.

### 3.4 Pipeline và timing

- Latency 5 chu kỳ
- Throughput 1 transform/cycle
- Tính f_max dự kiến

### 3.5 Ước lượng tài nguyên

| Resource          | Estimate |
| ----------------- | -------: |
| 16×16 multipliers |       12 |
| Slice LUT         |    ~1500 |
| Slice FF          |     ~800 |
| f_max (7-series)  | ~150 MHz |

---

## CHƯƠNG 4 — MÔ PHỎNG VÀ KIỂM TRA (5 trang)

### 4.1 Môi trường mô phỏng

- Icarus Verilog 12.0
- ModelSim/Questa (tuỳ chọn)
- GTKWave
- Python 3 + NumPy

### 4.2 Testbench

- Cấu trúc tb_fft8.v
- Phương pháp directed test
- Pack/unpack sample bus
- Tolerance check

### 4.3 Test cases và kết quả

| #   | Input        | Expected        | Got | Pass |
| --- | ------------ | --------------- | --- | ---- |
| 1   | Impulse      | X[k] = 4095 ∀ k | …   | ✓    |
| 2   | Constant 0.5 | X[0]=16384, ∅   | …   | ✓    |
| 3   | Cosine bin 1 | Peak bin 1, 7   | …   | ✓    |

### 4.4 Waveform mô phỏng

Chèn screenshot GTKWave/ModelSim:

- Reset / valid_in / x_in
- Tín hiệu giữa các stage
- valid_out / X_out

### 4.5 So sánh với Python NumPy

Bảng so sánh 3 test, sai số RMS tính theo Q1.15 LSB.

---

## CHƯƠNG 5 — TỔNG HỢP VÀ KẾT QUẢ (3 trang)

### 5.1 Synthesis với Vivado/Quartus

- Cấu hình project
- Constraint clock
- Báo cáo Utilization
- Báo cáo Timing
- f_max đạt được

### 5.2 Đánh giá tài nguyên

So sánh với spec dự kiến trong Chương 3.

### 5.3 So sánh với IP Xilinx

So sánh sơ bộ về LUT/FF/DSP với Xilinx FFT IP.

---

## CHƯƠNG 6 — KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN (2 trang)

### 6.1 Kết quả đạt được

- ✓ Thiết kế hoàn chỉnh FFT 8-point Q1.15 RTL
- ✓ 3/3 test pass
- ✓ Tài nguyên synthesis hợp lý
- ✓ Đối chiếu Python pass

### 6.2 Hạn chế

- Cố định N = 8
- Chưa hỗ trợ AXI-Stream
- Chưa làm IFFT

### 6.3 Hướng phát triển

- Mở rộng N = 16/32/64
- Thêm AXI4-Stream
- IFFT (đảo dấu twiddle)
- Floating-point FP32

---

## TÀI LIỆU THAM KHẢO (1 trang)

[1] J. W. Cooley and J. W. Tukey, "An Algorithm for the Machine Calculation of Complex Fourier Series," 1965.

[2] A. V. Oppenheim and R. W. Schafer, _Discrete-Time Signal Processing_, 3rd ed.

[3] Xilinx UG901, _Vivado Synthesis User Guide_.

[4] Saleh, "Fixed-Point FFT Architectures," IEEE.

[5] M. Frigo and S. Johnson, "The Design and Implementation of FFTW3," Proceedings of the IEEE, 2005.

---

## PHỤ LỤC (kèm theo, không tính trang chính)

- A. Source code Verilog đầy đủ
- B. Source code Python verify
- C. Log mô phỏng
- D. Báo cáo synthesis
