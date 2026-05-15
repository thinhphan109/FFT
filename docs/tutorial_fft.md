# 🎓 FFT for Beginners — Hướng dẫn FFT từ Zero đến Hero

> Dành cho người **chưa biết gì** về FFT, Verilog, hay xử lý tín hiệu số.
> Mục tiêu: đọc xong là **hiểu nguyên lý**, **biết tính tay**, **đọc được code**, và **chạy được mô phỏng**.

---

## 📑 Mục lục

1. [Tại sao cần FFT?](#1-tại-sao-cần-fft)
2. [Tín hiệu số là gì?](#2-tín-hiệu-số-là-gì)
3. [DFT — biến đổi rời rạc](#3-dft--biến-đổi-rời-rạc)
4. [Số phức cơ bản](#4-số-phức-cơ-bản)
5. [Twiddle factor — cái xoay xoay](#5-twiddle-factor--cái-xoay-xoay)
6. [Từ DFT sang FFT — chia để trị](#6-từ-dft-sang-fft--chia-để-trị)
7. [Butterfly — đơn vị tính cốt lõi](#7-butterfly--đơn-vị-tính-cốt-lõi)
8. [Bit-reversal — tại sao thứ tự bị đảo](#8-bit-reversal--tại-sao-thứ-tự-bị-đảo)
9. [FFT 8 điểm — vẽ đầy đủ trên giấy](#9-fft-8-điểm--vẽ-đầy-đủ-trên-giấy)
10. [Tính tay từng bước một ví dụ](#10-tính-tay-từng-bước-một-ví-dụ)
11. [Số fixed-point Q1.15](#11-số-fixed-point-q115)
12. [Cú pháp Verilog cần biết](#12-cú-pháp-verilog-cần-biết)
13. [Đọc từng module trong project](#13-đọc-từng-module-trong-project)
14. [Cách chạy mô phỏng](#14-cách-chạy-mô-phỏng)
15. [Đọc waveform GTKWave](#15-đọc-waveform-gtkwave)
16. [Bài tập thực hành](#16-bài-tập-thực-hành)
17. [FAQ — câu hỏi thường gặp](#17-faq--câu-hỏi-thường-gặp)

---

## 1. Tại sao cần FFT?

Tưởng tượng bạn ghi âm một đoạn nhạc. File âm thanh là một dãy số:

```
âm thanh = [0.1, 0.3, 0.5, 0.4, ...]
```

Đó là **biểu diễn theo thời gian** — mỗi số là biên độ ở một thời điểm.

Nhưng tai người **nghe theo tần số**: bass thấp, treble cao. Làm sao biến dãy số này thành "ở tần số 100 Hz có bao nhiêu năng lượng"?

> **FFT chính là phép biến đổi từ miền thời gian sang miền tần số.**

### Ứng dụng thực tế

| Lĩnh vực           | FFT làm gì                                         |
| ------------------ | -------------------------------------------------- |
| 📱 Wi-Fi / 4G / 5G | OFDM dùng IFFT phía phát, FFT phía thu             |
| 🎵 MP3 / AAC       | Phân tích phổ → loại bỏ tần số tai không nghe được |
| 🖼️ JPEG            | DCT (họ FFT) nén ảnh                               |
| 🛰️ Radar           | Phát hiện vận tốc qua hiệu ứng Doppler             |
| 🎚️ Equalizer       | Tăng/giảm bass/treble                              |
| 🩺 ECG             | Tách nhịp tim khỏi nhiễu 50Hz                      |

---

## 2. Tín hiệu số là gì?

Một tín hiệu **liên tục** (analog):

```
sóng sin: x(t) = sin(2π·f·t)
```

Khi đưa vào ADC, ta lấy mẫu (sampling) tại các thời điểm rời rạc:

```
x[0], x[1], x[2], ..., x[N-1]
```

Đó là tín hiệu **rời rạc**.  
`N` = số mẫu. Ở đồ án này **N = 8**.

### Ví dụ

Sóng sin biên độ 1, lấy 8 mẫu trong 1 chu kỳ:

```
n     0       1       2       3       4       5       6       7
x[n]  0.000   0.707   1.000   0.707   0.000  -0.707  -1.000  -0.707
```

---

## 3. DFT — biến đổi rời rạc

**Discrete Fourier Transform** biến `x[n]` (8 số thực) thành `X[k]` (8 số phức):

```
       N-1
X[k] =  Σ   x[n] · e^(-j·2π·k·n/N)        k = 0, 1, ..., N-1
       n=0
```

### Diễn giải bằng lời

Với mỗi tần số `k` (từ 0 đến N-1):

> "Nhân `x[n]` với một sóng sin/cos tần số `k`, rồi cộng lại. Kết quả cho biết tín hiệu có chứa bao nhiêu thành phần ở tần số đó."

### Số phép tính cần

- N = 8 → cần **64 phép nhân phức** + **56 phép cộng phức**
- N = 1024 → cần **~1 triệu phép nhân**!

→ Quá chậm. Đây chính là lý do người ta phát minh ra FFT.

---

## 4. Số phức cơ bản

Số phức có dạng:

```
z = a + j·b
```

trong đó `j² = -1` (kỹ sư điện viết là `j`, toán học viết là `i`).

### Phép cộng

```
(a + jb) + (c + jd) = (a+c) + j(b+d)
```

Ví dụ: `(2 + j3) + (1 - j5) = 3 - j2`

### Phép nhân (cẩn thận!)

```
(a + jb) · (c + jd) = (ac - bd) + j(ad + bc)
```

Ví dụ: `(1 + j) · (1 - j) = 1·1 - 1·(-1) + j(1·(-1) + 1·1) = 2 + j0`

> 💡 **Nhớ:** phần thực = `ac - bd`, phần ảo = `ad + bc`

### Công thức Euler

```
e^(jθ) = cos(θ) + j·sin(θ)
```

Đây là chìa khóa của FFT vì:

```
e^(-j·2π·k·n/N) = cos(2πkn/N) - j·sin(2πkn/N)
```

---

## 5. Twiddle factor — cái xoay xoay

**Twiddle factor** ký hiệu là `W_N^k`:

```
W_N^k = e^(-j·2π·k/N)
```

Đây chỉ là một số phức nằm trên **vòng tròn đơn vị**.

### Với N = 8

```
W_8^k = e^(-j·2π·k/8) = e^(-j·πk/4)
```

| k   | Góc (rad) | Re = cos(θ) | Im = -sin(θ) | Vị trí trên vòng tròn |
| --- | --------: | ----------: | -----------: | --------------------- |
| 0   |         0 |       1.000 |        0.000 | ngay trục Re dương    |
| 1   |      -π/4 |       0.707 |       -0.707 | quay xuống 45°        |
| 2   |      -π/2 |       0.000 |       -1.000 | trục Im âm            |
| 3   |     -3π/4 |      -0.707 |       -0.707 | góc dưới trái         |
| 4   |        -π |      -1.000 |        0.000 | trục Re âm            |
| 5   |     -5π/4 |      -0.707 |        0.707 | góc trên trái         |
| 6   |     -3π/2 |       0.000 |        1.000 | trục Im dương         |
| 7   |     -7π/4 |       0.707 |        0.707 | góc trên phải         |

### Mẹo nhớ

```
W_8^4 = -W_8^0     W_8^5 = -W_8^1     W_8^6 = -W_8^2     W_8^7 = -W_8^3
```

⇒ Chỉ cần lưu **4 hệ số đầu**, các hệ số sau đảo dấu là ra. Đó là lý do `twiddle_rom.v` chỉ có 4 entry.

### Sơ đồ vòng tròn đơn vị

```
                    Im
                    ↑
              W₈⁶  │  W₈⁷
                ●  │  ●
            ●      │      ●
         W₈⁵       │        W₈⁰
       ●           │           ●  → Re
         W₈⁴       │        W₈¹
            ●      │      ●
                ●  │  ●
              W₈³  │  W₈²
                    ↓
```

---

## 6. Từ DFT sang FFT — chia để trị

DFT chậm vì làm `N²` phép nhân. FFT nhanh nhờ thủ thuật **divide and conquer**.

### Ý tưởng

Tách `x[n]` thành 2 nhóm:

- **Chẵn:** `x[0], x[2], x[4], x[6]`
- **Lẻ:** `x[1], x[3], x[5], x[7]`

Tính DFT của 2 nhóm nhỏ riêng (mỗi cái N/2 = 4 điểm), rồi **kết hợp lại** bằng vài phép cộng/nhân.

```
DFT 8 điểm  =  DFT 4 điểm (chẵn)  +  W·DFT 4 điểm (lẻ)
```

Áp dụng đệ quy: DFT 4 điểm = 2 DFT 2 điểm. DFT 2 điểm là butterfly cơ bản.

### So sánh số phép tính

|    N |  DFT (N²) | FFT (N·log₂N) | Tăng tốc |
| ---: | --------: | ------------: | -------: |
|    8 |        64 |            24 |     2.7× |
|   64 |      4096 |           384 |    10.7× |
| 1024 | 1,048,576 |        10,240 |     102× |
| 4096 |       16M |           49K |     341× |

→ Càng N lớn, FFT càng có lợi thế khủng khiếp.

---

## 7. Butterfly — đơn vị tính cốt lõi

**Butterfly** là phép biến đổi 2 đầu vào → 2 đầu ra:

```
A ──────●────[+]──── y0 = A + B·W
        │     │
        │    [-]──── y1 = A - B·W
        │     │
B ──[×W]●─────┘
```

Vẽ ra giống cánh bướm → tên gọi "butterfly".

### Ví dụ tính tay

Cho `A = 2 + j0`, `B = 1 + j0`, `W = 1 + j0`:

```
B·W = (1+j0)·(1+j0) = 1+j0
y0  = A + B·W = (2+j0) + (1+j0) = 3+j0
y1  = A - B·W = (2+j0) - (1+j0) = 1+j0
```

### Tại sao chia 1/2 trong RTL?

Phần cứng làm Q1.15 → `[-1, +1)`. Nếu `A = 0.9` và `B·W = 0.9` thì `y0 = 1.8` → **tràn**!

Giải pháp: chia 2 ngay tại butterfly:

```
y0 = (A + B·W) / 2
y1 = (A - B·W) / 2
```

Sau 3 stage thì tổng scale là `1/2³ = 1/8 = 1/N` → kết quả khớp với `numpy.fft.fft(x) / N`.

Đó là lý do trong code có dòng:

```verilog
assign y0_re = sum_re >>> 1;   // shift right = chia 2
assign y0_im = sum_im >>> 1;
assign y1_re = dif_re >>> 1;
assign y1_im = dif_im >>> 1;
```

---

## 8. Bit-reversal — tại sao thứ tự bị đảo

Khi tách chẵn/lẻ đệ quy, thứ tự đầu vào bị xáo trộn.

### Ví dụ N = 8

| index thường | binary | reversed | index thực dùng |
| -----------: | ------ | -------- | --------------: |
|            0 | 000    | 000      |               0 |
|            1 | 001    | 100      |               4 |
|            2 | 010    | 010      |               2 |
|            3 | 011    | 110      |               6 |
|            4 | 100    | 001      |               1 |
|            5 | 101    | 101      |               5 |
|            6 | 110    | 011      |               3 |
|            7 | 111    | 111      |               7 |

→ Thứ tự đảo: `0, 4, 2, 6, 1, 5, 3, 7`

Trong `fft8_core.v` ta hard-wire:

```verilog
assign s0_re[0] = x_re_flat[`IDX(0)];
assign s0_re[1] = x_re_flat[`IDX(4)];
assign s0_re[2] = x_re_flat[`IDX(2)];
assign s0_re[3] = x_re_flat[`IDX(6)];
assign s0_re[4] = x_re_flat[`IDX(1)];
...
```

Output thì ra theo thứ tự **bình thường** `0, 1, 2, ..., 7`.

> 💡 Có 2 trường phái: DIT đảo input + output đúng thứ tự (đồ án này), DIF input đúng + output đảo. Cả hai đều đúng.

---

## 9. FFT 8 điểm — vẽ đầy đủ trên giấy

```
        Stage 1            Stage 2            Stage 3
        (W₂⁰=1)            (W₄⁰, W₄¹=W₈²)     (W₈⁰, W₈¹, W₈², W₈³)

x[0]  ──●──────────●─────────●────────── X[0]
        │          │         │
x[4]  ──●──[×1]────●         │         ── X[1]
                   │         │
x[2]  ──●──────────●──[×1]───●────────── X[2]
        │          │         │
x[6]  ──●──[×1]────●──[×-j]──●         ── X[3]
                             │
x[1]  ──●──────────●─────────●──[×1]──── X[4]
        │          │         │
x[5]  ──●──[×1]────●         │── [×0.7-0.7j]
                   │         │
x[3]  ──●──────────●──[×1]───● ──[×-j]── X[6]
        │          │         │
x[7]  ──●──[×1]────●──[×-j]──● ──[×-0.7-0.7j]
```

### Liệt kê 12 butterfly

| Stage | Pair              | Twiddle             |
| ----- | ----------------- | ------------------- |
| 1     | (0,1)=(x[0],x[4]) | W₂⁰ = 1             |
| 1     | (2,3)=(x[2],x[6]) | W₂⁰ = 1             |
| 1     | (4,5)=(x[1],x[5]) | W₂⁰ = 1             |
| 1     | (6,7)=(x[3],x[7]) | W₂⁰ = 1             |
| 2     | (0,2)             | W₄⁰ = 1             |
| 2     | (1,3)             | W₄¹ = -j            |
| 2     | (4,6)             | W₄⁰ = 1             |
| 2     | (5,7)             | W₄¹ = -j            |
| 3     | (0,4)             | W₈⁰ = 1             |
| 3     | (1,5)             | W₈¹ = 0.707-0.707j  |
| 3     | (2,6)             | W₈² = -j            |
| 3     | (3,7)             | W₈³ = -0.707-0.707j |

→ Đúng 12 butterfly = `(N/2) · log₂(N)` = `4 · 3 = 12`.

---

## 10. Tính tay từng bước một ví dụ

**Input:** `x = [1, 0, 0, 0, 0, 0, 0, 0]` (impulse)

### Bước 1 — bit reversal

```
input order   : x[0] x[1] x[2] x[3] x[4] x[5] x[6] x[7]
                 1    0    0    0    0    0    0    0

reordered     : x[0] x[4] x[2] x[6] x[1] x[5] x[3] x[7]
                 1    0    0    0    0    0    0    0
```

### Bước 2 — Stage 1 (4 butterfly với W=1)

```
BF(1, 0)  →  y0 = (1+0)/2 = 0.5    y1 = (1-0)/2 = 0.5
BF(0, 0)  →  y0 = 0                y1 = 0
BF(0, 0)  →  y0 = 0                y1 = 0
BF(0, 0)  →  y0 = 0                y1 = 0
```

Sau Stage 1:

```
[0.5, 0.5, 0, 0, 0, 0, 0, 0]
```

### Bước 3 — Stage 2

```
BF(0.5, 0)        W₄⁰=1     →  (0.5)/2=0.25     (0.5)/2=0.25
BF(0.5, 0)        W₄¹=-j    →  (0.5)/2=0.25     (0.5)/2=0.25
BF(0, 0)          W₄⁰=1     →  0                0
BF(0, 0)          W₄¹=-j    →  0                0
```

Sau Stage 2:

```
[0.25, 0.25, 0.25, 0.25, 0, 0, 0, 0]
```

### Bước 4 — Stage 3

```
BF(0.25, 0)       W₈⁰=1                        →  0.125    0.125
BF(0.25, 0)       W₈¹=0.707-0.707j             →  0.125    0.125
BF(0.25, 0)       W₈²=-j                       →  0.125    0.125
BF(0.25, 0)       W₈³=-0.707-0.707j            →  0.125    0.125
```

### Kết quả cuối

```
X = [0.125, 0.125, 0.125, 0.125, 0.125, 0.125, 0.125, 0.125]
  = [1/8, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8]
```

Nhân với 32768 (Q1.15) → **4096** ✓ giống Verilog output (`4095` do truncation).

> 🎯 **Lý thuyết:** impulse có biên độ phẳng trên mọi tần số. Đúng như kết quả!

---

## 11. Số fixed-point Q1.15

### Tại sao không dùng float?

- Float (32-bit IEEE 754) tốn ~1000 LUT cho 1 phép nhân
- Fixed-point Q1.15 chỉ cần 1 DSP block 16×16
- → Phần cứng nhỏ hơn 10–20 lần

### Q1.15 là gì?

```
Bit:  15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 0
      ┌──┬─────────────────────────────────┐
      │S │ 15 bit phần phân                  │
      └──┴─────────────────────────────────┘
       sign
```

- 1 bit dấu
- 15 bit phân số
- Giá trị nguyên thuần khoảng `[-32768, +32767]`
- Được hiểu là `[-1.0, +1.0)` bằng cách chia cho 2¹⁵ = 32768

### Bảng chuyển đổi

|  Float |         Tính |      Q1.15 (decimal) | Q1.15 (hex) |
| -----: | -----------: | -------------------: | ----------: |
|   +1.0 |  1.0 × 32768 | 32768 (tràn → 32767) |      0x7FFF |
|   +0.5 |  0.5 × 32768 |                16384 |      0x4000 |
|  +0.25 | 0.25 × 32768 |                 8192 |      0x2000 |
|    0.0 |            — |                    0 |      0x0000 |
|   -0.5 | -0.5 × 32768 |               -16384 |      0xC000 |
|   -1.0 | -1.0 × 32768 |               -32768 |      0x8000 |
| 0.7071 | 0.7071×32768 |                23170 |      0x5A82 |

### Phép nhân Q1.15

```
Q1.15 × Q1.15 = Q2.30 (32 bit)
```

Để trở về Q1.15 cần lấy bit `[30:15]`:

```verilog
wire signed [31:0] m = a * b;       // Q2.30
wire signed [15:0] result = m[30:15]; // Q1.15 (truncate)
```

### Ví dụ

```
0.5 × 0.5 = 0.25
16384 × 16384 = 268,435,456 (Q2.30)
                = 0x10000000
lấy bit [30:15] = 0x2000 = 8192 (Q1.15) ✓ (đúng 0.25)
```

---

## 12. Cú pháp Verilog cần biết

### Khai báo module

```verilog
module ten_module #(
    parameter W = 16          // tham số (giá trị mặc định 16)
)(
    input             clk,    // 1-bit input
    input  [W-1:0]    a,      // W-bit input
    output [W-1:0]    y       // W-bit output
);
    // body
endmodule
```

### Wire vs reg

| Loại   | Khi dùng                     | Gán bằng        |
| ------ | ---------------------------- | --------------- |
| `wire` | logic tổ hợp (combinational) | `assign`        |
| `reg`  | logic tuần tự (sequential)   | `always @(...)` |

### Số có dấu

```verilog
reg signed [15:0] x;             // signed 16-bit
wire signed [15:0] y;
y = x >>> 1;                     // arithmetic shift right (giữ dấu)
y = x  >> 1;                     // logical shift right (KHÔNG giữ dấu) ⚠️
```

### Số literal

```verilog
16'd32767       // 16-bit decimal
16'h7FFF        // 16-bit hex
16'b0111_..._1  // 16-bit binary
16'sd-1         // signed -1
```

### Always block

```verilog
// Sequential (có clock)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        q <= 16'd0;       // non-blocking <=
    else
        q <= d;
end

// Combinational
always @(*) begin
    case (sel)
        2'd0: y = a;
        2'd1: y = b;
        default: y = 16'd0;
    endcase
end
```

### Generate

Tạo nhiều instance giống nhau:

```verilog
genvar i;
generate
    for (i = 0; i < 4; i = i + 1) begin : G_BF
        butterfly u (...);
    end
endgenerate
```

### Pack/unpack array

Verilog 2001 không hỗ trợ truyền array qua port → ta phải "pack" thành vector lớn:

```verilog
input [8*16-1:0] x_flat;          // 8 sample × 16 bit = 128 bit
wire [15:0] x [0:7];               // unpack ra mảng

genvar i;
generate
    for (i = 0; i < 8; i = i + 1)
        assign x[i] = x_flat[i*16 +: 16];   // chú ý cú pháp +:
endgenerate
```

`[i*16 +: 16]` nghĩa là: lấy 16 bit bắt đầu từ vị trí `i*16`.

---

## 13. Đọc từng module trong project

### 13.1 `complex_mul.v` — nhân số phức

```verilog
wire signed [31:0] m_rr = a_re * b_re;   // (real × real)
wire signed [31:0] m_ii = a_im * b_im;   // (imag × imag)
wire signed [31:0] m_ri = a_re * b_im;   // (real × imag)
wire signed [31:0] m_ir = a_im * b_re;   // (imag × real)

wire signed [31:0] real_full = m_rr - m_ii;
wire signed [31:0] imag_full = m_ri + m_ir;

assign y_re = real_full[30:15];   // truncate Q2.30 → Q1.15
assign y_im = imag_full[30:15];
```

> Đây chính là công thức `(a+jb)(c+jd) = (ac-bd) + j(ad+bc)`.

### 13.2 `butterfly.v` — butterfly Radix-2

```verilog
complex_mul u_mul (.a_re(b_re), .a_im(b_im), .b_re(w_re), .b_im(w_im),
                   .y_re(bw_re), .y_im(bw_im));

wire signed [16:0] sum_re = $signed({a_re[15], a_re}) + $signed({bw_re[15], bw_re});
wire signed [16:0] dif_re = $signed({a_re[15], a_re}) - $signed({bw_re[15], bw_re});

assign y0_re = sum_re >>> 1;   // chia 2
assign y1_re = dif_re >>> 1;
```

> `{a_re[15], a_re}` = sign-extend 16-bit thành 17-bit để cộng/trừ không tràn, sau đó shift right 1 = chia 2.

### 13.3 `twiddle_rom.v` — bảng tra hệ số

```verilog
case (k)
    2'd0: begin w_re =  16'sd32767; w_im =  16'sd0;     end
    2'd1: begin w_re =  16'sd23170; w_im = -16'sd23170; end
    2'd2: begin w_re =  16'sd0;     w_im = -16'sd32768; end
    2'd3: begin w_re = -16'sd23170; w_im = -16'sd23170; end
endcase
```

### 13.4 `fft8_core.v` — lõi 3 stage

```verilog
// Stage 1: 4 butterfly, twiddle = 1
generate
    for (gi = 0; gi < 4; gi = gi + 1) begin : G_STAGE1
        butterfly u_bf (
            .a_re(s0_re[2*gi]),    .a_im(s0_im[2*gi]),
            .b_re(s0_re[2*gi+1]),  .b_im(s0_im[2*gi+1]),
            .w_re(W8_0_RE),        .w_im(W8_0_IM),
            .y0_re(s1c_re[2*gi]),  .y0_im(s1c_im[2*gi]),
            .y1_re(s1c_re[2*gi+1]),.y1_im(s1c_im[2*gi+1])
        );
    end
endgenerate
```

3 stage ⇒ 3 thanh ghi pipeline ⇒ latency = 3 (chưa kể IR + OR ở top).

### 13.5 `fft8_top.v` — wrapper

Thêm 2 thanh ghi I/O. Total latency = `1 + 3 + 1 = 5` clock.

---

## 14. Cách chạy mô phỏng

### Cài Icarus Verilog

**Windows (qua scoop):**

```powershell
scoop install iverilog
```

**Linux (Ubuntu):**

```bash
sudo apt install iverilog gtkwave
```

**macOS:**

```bash
brew install icarus-verilog gtkwave
```

### Compile + Run

```bash
cd fft_project
iverilog -g2012 -o sim/fft8.vvp \
    rtl/complex_mul.v rtl/butterfly.v rtl/twiddle_rom.v \
    rtl/fft8_core.v rtl/fft8_top.v tb/tb_fft8.v
vvp sim/fft8.vvp
```

### Output mong đợi

```
[100000] === Test 1: Impulse ===
  X[0] = (  4095,      0)
  X[1] = (  4095,      0)
  ...
  X[7] = (  4095,      0)
[160000] === Test 2: Constant 0.5 ===
  X[0] = ( 16381,      0)
  ...
[220000] === Test 3: Cosine bin=1 ===
  X[1] = (  8191,      0)
  X[7] = (  8192,      0)
=========================================
  ALL TESTS PASSED
=========================================
```

### So sánh với Python

```bash
python python/verify_fft.py
```

Output Q1.15 hai bên phải khớp ±3 LSB.

---

## 15. Đọc waveform GTKWave

```bash
gtkwave fft8.vcd
```

### Các tín hiệu nên xem

| Signal                   | Ý nghĩa                     |
| ------------------------ | --------------------------- |
| `clk`                    | xung clock                  |
| `rst_n`                  | reset active-low            |
| `valid_in`               | có sample mới               |
| `x_re_flat`, `x_im_flat` | 8 sample đóng gói (xem hex) |
| `s1_re`, `s1_im`         | giữa stage 1-2              |
| `s2_re`, `s2_im`         | giữa stage 2-3              |
| `valid_out`              | output sẵn sàng             |
| `X_re_flat`, `X_im_flat` | kết quả FFT                 |

### Đo latency

Đo từ khi `valid_in=1` đến khi `valid_out=1`. Phải bằng **5 chu kỳ clock**.

---

## 16. Bài tập thực hành

### 🎯 Bài 1 — Đọc input mới

Sửa testbench để input là `x = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]`. Quan sát output. Có DC component không?

**Gợi ý:** trung bình = 0.45 → `X[0] = 0.45` (Q1.15: ~14745).

### 🎯 Bài 2 — Sóng vuông

Input là sóng vuông 4 high + 4 low: `[1, 1, 1, 1, -1, -1, -1, -1]` (Q1.15: ±32767).

Vẽ phổ. Bin nào cao nhất?

### 🎯 Bài 3 — IFFT

Sửa file `twiddle_rom.v`: đổi dấu phần ảo (`w_im` → `-w_im`). Đổi tên thành `ifft8`.

Test: cho input là output của FFT đã chạy ở bài 1. IFFT phải trả về tín hiệu gốc.

### 🎯 Bài 4 — Mở rộng FFT-16

Hãy thiết kế `fft16_core.v`:

- Bit-reversal cho 16 index (4-bit)
- 4 stage thay vì 3
- 32 butterfly thay vì 12
- 8 hệ số twiddle W₁₆⁰..W₁₆⁷

### 🎯 Bài 5 — Đo độ chính xác

Viết script Python so sánh từng giá trị Verilog vs NumPy, in ra **MSE** (mean square error). Mục tiêu MSE < 100 LSB².

---

## 17. FAQ — câu hỏi thường gặp

### Q1. Tại sao output Verilog là 4095 mà Python ra 4096?

Do Q1.15 truncation (bỏ bit thấp khi nhân). Sai lệch ±1-3 LSB là chấp nhận được.

### Q2. Sao phải dùng số phức? Tín hiệu thực mà.

Vì cosin/sin được biểu diễn gọn bằng `e^(jθ)`. Output FFT cũng là số phức để chứa cả biên độ + pha.

### Q3. Tại sao output có cả X[k] và X[N-k] giống nhau?

Vì input thực ⇒ X có **đối xứng Hermitian**: `X[N-k] = conj(X[k])`. Bin 1 và bin 7 luôn giống nhau khi input thực.

### Q4. Tần số bin k tương ứng với bao nhiêu Hz?

```
f_k = k · f_s / N
```

Với f_s = sampling rate. VD f_s = 8 kHz, N = 8 → mỗi bin cách 1 kHz.

### Q5. Có cần synchronizer khi đọc output không?

Không, vì pipe synchronous toàn bộ. Chỉ cần synchronizer khi đi giữa 2 clock domain.

### Q6. Tại sao chia 1/2 mỗi stage thay vì 1/N một lần?

Để **tránh tràn ngay** sau mỗi stage. Nếu chỉ chia 1/N ở cuối thì giữa chừng có thể tràn 16-bit Q1.15.

### Q7. Sao không dùng `*` trực tiếp trong butterfly?

Vẫn dùng được, nhưng `complex_mul` đóng gói lại cho dễ tái sử dụng + dễ thay bằng DSP block khi synthesis.

### Q8. Pipeline có cần valid signal không?

Có. `valid_out` cho biết khi nào output đã hợp lệ (sau 5 cycle).

### Q9. Test cosin ra `X[1] = 8191` thay vì `16384` có đúng không?

**Đúng.** Vì input cosin có 2 thành phần đối xứng:

```
0.5·cos(θ) = 0.25·e^(jθ) + 0.25·e^(-jθ)
            ↑               ↑
          bin 1            bin 7
```

Mỗi bin chứa 0.25 → Q1.15 = 8192. Verilog ra 8191 do truncation.

### Q10. Nên học gì tiếp sau FFT?

- IFFT (đảo dấu twiddle)
- FFT pipeline streaming
- Radix-4 FFT (nhanh hơn)
- AXI4-Stream wrapper
- Mixed-radix FFT (cho N không phải lũy thừa 2)

---

## 🎓 Tài liệu đọc thêm

| Tài liệu                                                      | Khi nào đọc              |
| ------------------------------------------------------------- | ------------------------ |
| Oppenheim & Schafer — _Discrete-Time Signal Processing_ Ch. 9 | Lý thuyết DSP đầy đủ     |
| Proakis — _Digital Signal Processing_                         | Bài tập + ví dụ          |
| Chu — _RTL Hardware Design Using VHDL_                        | Phần cứng pipeline       |
| Xilinx PG109 — _Fast Fourier Transform LogiCORE_              | Tham khảo IP công nghiệp |
| The Scientist and Engineer's Guide to DSP — dspguide.com      | Free, dễ đọc             |

---

## 🚀 Sau khi học xong

Bạn đã hiểu:

- ✅ FFT làm gì và tại sao cần
- ✅ Butterfly + twiddle factor
- ✅ Bit-reversal và 3 stage
- ✅ Q1.15 fixed-point arithmetic
- ✅ Cú pháp Verilog đủ để đọc/sửa code
- ✅ Cách chạy mô phỏng và verify
- ✅ Tự làm bài tập mở rộng

> 💪 Giờ bạn đã sẵn sàng bảo vệ đồ án FFT 8 điểm!
