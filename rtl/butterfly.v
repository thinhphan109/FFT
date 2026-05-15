//==============================================================================
// File         : butterfly.v
// Description  : Radix-2 Butterfly Unit (Decimation-In-Time)
//
//                  A ----+----[+]---- y0 = (A + B*W) / 2
//                        |     |
//                        |    [-]---- y1 = (A - B*W) / 2
//                        |     |
//                  B ----[*W]--+
//
//                Scaling by 1/2 each stage prevents overflow.
//                After 3 stages of an 8-point FFT the output is FFT/N (1/8).
//==============================================================================
`timescale 1ns/1ps

module butterfly #(
    parameter W = 16
)(
    input  signed [W-1:0] a_re,
    input  signed [W-1:0] a_im,
    input  signed [W-1:0] b_re,
    input  signed [W-1:0] b_im,
    input  signed [W-1:0] w_re,
    input  signed [W-1:0] w_im,
    output signed [W-1:0] y0_re,
    output signed [W-1:0] y0_im,
    output signed [W-1:0] y1_re,
    output signed [W-1:0] y1_im
);

    // B * W
    wire signed [W-1:0] bw_re;
    wire signed [W-1:0] bw_im;

    complex_mul #(.W(W)) u_mul (
        .a_re (b_re),
        .a_im (b_im),
        .b_re (w_re),
        .b_im (w_im),
        .y_re (bw_re),
        .y_im (bw_im)
    );

    // Sum/Diff with bit growth, then scale by 1/2 (arithmetic shift right)
    wire signed [W:0] sum_re = $signed({a_re[W-1], a_re}) + $signed({bw_re[W-1], bw_re});
    wire signed [W:0] sum_im = $signed({a_im[W-1], a_im}) + $signed({bw_im[W-1], bw_im});
    wire signed [W:0] dif_re = $signed({a_re[W-1], a_re}) - $signed({bw_re[W-1], bw_re});
    wire signed [W:0] dif_im = $signed({a_im[W-1], a_im}) - $signed({bw_im[W-1], bw_im});

    assign y0_re = sum_re >>> 1;
    assign y0_im = sum_im >>> 1;
    assign y1_re = dif_re >>> 1;
    assign y1_im = dif_im >>> 1;

endmodule
