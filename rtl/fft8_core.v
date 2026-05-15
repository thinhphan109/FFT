//==============================================================================
// File         : fft8_core.v
// Description  : 8-point Radix-2 Decimation-In-Time FFT Core
//                - Fixed-point Q1.15 (16-bit signed)
//                - Parallel input / parallel output (8 complex samples)
//                - 3 pipeline stages (one register stage between FFT stages)
//                - Output is scaled by 1/N = 1/8 (one >>1 per stage)
//
//                Architecture:
//                   bit_reverse -> Stage1 [pipe] -> Stage2 [pipe] -> Stage3 [pipe]
//
//                Stage twiddles (DIT, N=8):
//                   Stage 1: W2^0 = 1                 (4 butterflies)
//                   Stage 2: W4^0 = 1, W4^1 = -j      (4 butterflies)
//                   Stage 3: W8^0..W8^3               (4 butterflies)
//
//                Latency  : 3 clock cycles
//                Throughput: 1 transform / cycle
//==============================================================================
`timescale 1ns/1ps

module fft8_core #(
    parameter W = 16
)(
    input                       clk,
    input                       rst_n,
    input                       valid_in,

    // Input: 8 complex samples, packed (sample 0 is in LSB-most position)
    input  signed [8*W-1:0]     x_re_flat,
    input  signed [8*W-1:0]     x_im_flat,

    output signed [8*W-1:0]     X_re_flat,
    output signed [8*W-1:0]     X_im_flat,
    output                      valid_out
);

    // ----------------------------------------------------------------------
    // Helper macros for accessing packed sample arrays
    // ----------------------------------------------------------------------
    `define IDX(i) ((i)*W) +: W

    // ----------------------------------------------------------------------
    // Bit-reversal of input indices: 0,1,2,3,4,5,6,7 -> 0,4,2,6,1,5,3,7
    // ----------------------------------------------------------------------
    wire signed [W-1:0] s0_re [0:7];
    wire signed [W-1:0] s0_im [0:7];

    assign s0_re[0] = x_re_flat[`IDX(0)];
    assign s0_re[1] = x_re_flat[`IDX(4)];
    assign s0_re[2] = x_re_flat[`IDX(2)];
    assign s0_re[3] = x_re_flat[`IDX(6)];
    assign s0_re[4] = x_re_flat[`IDX(1)];
    assign s0_re[5] = x_re_flat[`IDX(5)];
    assign s0_re[6] = x_re_flat[`IDX(3)];
    assign s0_re[7] = x_re_flat[`IDX(7)];

    assign s0_im[0] = x_im_flat[`IDX(0)];
    assign s0_im[1] = x_im_flat[`IDX(4)];
    assign s0_im[2] = x_im_flat[`IDX(2)];
    assign s0_im[3] = x_im_flat[`IDX(6)];
    assign s0_im[4] = x_im_flat[`IDX(1)];
    assign s0_im[5] = x_im_flat[`IDX(5)];
    assign s0_im[6] = x_im_flat[`IDX(3)];
    assign s0_im[7] = x_im_flat[`IDX(7)];

    // ----------------------------------------------------------------------
    // Twiddle factors (Q1.15)
    // ----------------------------------------------------------------------
    localparam signed [W-1:0] W8_0_RE =  16'sd32767;
    localparam signed [W-1:0] W8_0_IM =  16'sd0;
    localparam signed [W-1:0] W8_1_RE =  16'sd23170;
    localparam signed [W-1:0] W8_1_IM = -16'sd23170;
    localparam signed [W-1:0] W8_2_RE =  16'sd0;
    localparam signed [W-1:0] W8_2_IM = -16'sd32768;
    localparam signed [W-1:0] W8_3_RE = -16'sd23170;
    localparam signed [W-1:0] W8_3_IM = -16'sd23170;

    // ----------------------------------------------------------------------
    // STAGE 1 : 4 butterflies, twiddle = W2^0 = 1
    // ----------------------------------------------------------------------
    wire signed [W-1:0] s1c_re [0:7];
    wire signed [W-1:0] s1c_im [0:7];

    genvar gi;
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : G_STAGE1
            butterfly #(.W(W)) u_bf (
                .a_re (s0_re[2*gi]),     .a_im (s0_im[2*gi]),
                .b_re (s0_re[2*gi+1]),   .b_im (s0_im[2*gi+1]),
                .w_re (W8_0_RE),         .w_im (W8_0_IM),
                .y0_re(s1c_re[2*gi]),    .y0_im(s1c_im[2*gi]),
                .y1_re(s1c_re[2*gi+1]),  .y1_im(s1c_im[2*gi+1])
            );
        end
    endgenerate

    // Pipeline register after Stage 1
    reg signed [W-1:0] s1_re [0:7];
    reg signed [W-1:0] s1_im [0:7];
    reg                v1;

    integer i1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v1 <= 1'b0;
            for (i1 = 0; i1 < 8; i1 = i1 + 1) begin
                s1_re[i1] <= {W{1'b0}};
                s1_im[i1] <= {W{1'b0}};
            end
        end else begin
            v1 <= valid_in;
            for (i1 = 0; i1 < 8; i1 = i1 + 1) begin
                s1_re[i1] <= s1c_re[i1];
                s1_im[i1] <= s1c_im[i1];
            end
        end
    end

    // ----------------------------------------------------------------------
    // STAGE 2 : 4 butterflies
    //   Pairs (0,2),(4,6) use W4^0 = W8^0 = 1
    //   Pairs (1,3),(5,7) use W4^1 = W8^2 = -j
    // ----------------------------------------------------------------------
    wire signed [W-1:0] s2c_re [0:7];
    wire signed [W-1:0] s2c_im [0:7];

    butterfly #(.W(W)) u_s2_bf0 (
        .a_re(s1_re[0]), .a_im(s1_im[0]),
        .b_re(s1_re[2]), .b_im(s1_im[2]),
        .w_re(W8_0_RE),  .w_im(W8_0_IM),
        .y0_re(s2c_re[0]), .y0_im(s2c_im[0]),
        .y1_re(s2c_re[2]), .y1_im(s2c_im[2])
    );
    butterfly #(.W(W)) u_s2_bf1 (
        .a_re(s1_re[1]), .a_im(s1_im[1]),
        .b_re(s1_re[3]), .b_im(s1_im[3]),
        .w_re(W8_2_RE),  .w_im(W8_2_IM),
        .y0_re(s2c_re[1]), .y0_im(s2c_im[1]),
        .y1_re(s2c_re[3]), .y1_im(s2c_im[3])
    );
    butterfly #(.W(W)) u_s2_bf2 (
        .a_re(s1_re[4]), .a_im(s1_im[4]),
        .b_re(s1_re[6]), .b_im(s1_im[6]),
        .w_re(W8_0_RE),  .w_im(W8_0_IM),
        .y0_re(s2c_re[4]), .y0_im(s2c_im[4]),
        .y1_re(s2c_re[6]), .y1_im(s2c_im[6])
    );
    butterfly #(.W(W)) u_s2_bf3 (
        .a_re(s1_re[5]), .a_im(s1_im[5]),
        .b_re(s1_re[7]), .b_im(s1_im[7]),
        .w_re(W8_2_RE),  .w_im(W8_2_IM),
        .y0_re(s2c_re[5]), .y0_im(s2c_im[5]),
        .y1_re(s2c_re[7]), .y1_im(s2c_im[7])
    );

    // Pipeline register after Stage 2
    reg signed [W-1:0] s2_re [0:7];
    reg signed [W-1:0] s2_im [0:7];
    reg                v2;

    integer i2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v2 <= 1'b0;
            for (i2 = 0; i2 < 8; i2 = i2 + 1) begin
                s2_re[i2] <= {W{1'b0}};
                s2_im[i2] <= {W{1'b0}};
            end
        end else begin
            v2 <= v1;
            for (i2 = 0; i2 < 8; i2 = i2 + 1) begin
                s2_re[i2] <= s2c_re[i2];
                s2_im[i2] <= s2c_im[i2];
            end
        end
    end

    // ----------------------------------------------------------------------
    // STAGE 3 : 4 butterflies
    //   Pair (0,4) -> W8^0
    //   Pair (1,5) -> W8^1
    //   Pair (2,6) -> W8^2
    //   Pair (3,7) -> W8^3
    // ----------------------------------------------------------------------
    wire signed [W-1:0] s3c_re [0:7];
    wire signed [W-1:0] s3c_im [0:7];

    butterfly #(.W(W)) u_s3_bf0 (
        .a_re(s2_re[0]), .a_im(s2_im[0]),
        .b_re(s2_re[4]), .b_im(s2_im[4]),
        .w_re(W8_0_RE),  .w_im(W8_0_IM),
        .y0_re(s3c_re[0]), .y0_im(s3c_im[0]),
        .y1_re(s3c_re[4]), .y1_im(s3c_im[4])
    );
    butterfly #(.W(W)) u_s3_bf1 (
        .a_re(s2_re[1]), .a_im(s2_im[1]),
        .b_re(s2_re[5]), .b_im(s2_im[5]),
        .w_re(W8_1_RE),  .w_im(W8_1_IM),
        .y0_re(s3c_re[1]), .y0_im(s3c_im[1]),
        .y1_re(s3c_re[5]), .y1_im(s3c_im[5])
    );
    butterfly #(.W(W)) u_s3_bf2 (
        .a_re(s2_re[2]), .a_im(s2_im[2]),
        .b_re(s2_re[6]), .b_im(s2_im[6]),
        .w_re(W8_2_RE),  .w_im(W8_2_IM),
        .y0_re(s3c_re[2]), .y0_im(s3c_im[2]),
        .y1_re(s3c_re[6]), .y1_im(s3c_im[6])
    );
    butterfly #(.W(W)) u_s3_bf3 (
        .a_re(s2_re[3]), .a_im(s2_im[3]),
        .b_re(s2_re[7]), .b_im(s2_im[7]),
        .w_re(W8_3_RE),  .w_im(W8_3_IM),
        .y0_re(s3c_re[3]), .y0_im(s3c_im[3]),
        .y1_re(s3c_re[7]), .y1_im(s3c_im[7])
    );

    // Output register
    reg signed [W-1:0] s3_re [0:7];
    reg signed [W-1:0] s3_im [0:7];
    reg                v3;

    integer i3;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v3 <= 1'b0;
            for (i3 = 0; i3 < 8; i3 = i3 + 1) begin
                s3_re[i3] <= {W{1'b0}};
                s3_im[i3] <= {W{1'b0}};
            end
        end else begin
            v3 <= v2;
            for (i3 = 0; i3 < 8; i3 = i3 + 1) begin
                s3_re[i3] <= s3c_re[i3];
                s3_im[i3] <= s3c_im[i3];
            end
        end
    end

    // ----------------------------------------------------------------------
    // Pack output
    // ----------------------------------------------------------------------
    genvar go;
    generate
        for (go = 0; go < 8; go = go + 1) begin : G_PACK
            assign X_re_flat[`IDX(go)] = s3_re[go];
            assign X_im_flat[`IDX(go)] = s3_im[go];
        end
    endgenerate

    assign valid_out = v3;

    `undef IDX

endmodule
