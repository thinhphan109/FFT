//==============================================================================
// File         : complex_mul.v
// Description  : Complex multiplier in fixed-point Q1.15
//                (a_re + j*a_im) * (b_re + j*b_im)
//                = (a_re*b_re - a_im*b_im) + j*(a_re*b_im + a_im*b_re)
//
//                Q1.15 x Q1.15 = Q2.30 (32 bits)
//                Truncate back to Q1.15 by selecting bits [2W-2 : W-1]
//==============================================================================
`timescale 1ns/1ps

module complex_mul #(
    parameter W = 16
)(
    input  signed [W-1:0] a_re,
    input  signed [W-1:0] a_im,
    input  signed [W-1:0] b_re,
    input  signed [W-1:0] b_im,
    output signed [W-1:0] y_re,
    output signed [W-1:0] y_im
);

    wire signed [2*W-1:0] m_rr = a_re * b_re;
    wire signed [2*W-1:0] m_ii = a_im * b_im;
    wire signed [2*W-1:0] m_ri = a_re * b_im;
    wire signed [2*W-1:0] m_ir = a_im * b_re;

    // Bit growth: subtraction/addition of two Q2.30 -> still Q2.30 magnitude
    // Truncate Q2.30 -> Q1.15 by taking bits [30:15]
    wire signed [2*W-1:0] real_full = m_rr - m_ii;
    wire signed [2*W-1:0] imag_full = m_ri + m_ir;

    assign y_re = real_full[2*W-2 : W-1];
    assign y_im = imag_full[2*W-2 : W-1];

endmodule
