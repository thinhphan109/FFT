//==============================================================================
// File         : fft8_top.v
// Description  : Top-level wrapper for 8-point FFT
//                Provides:
//                  - Input register (sync sample bus)
//                  - Instantiates fft8_core
//                  - Output register
//==============================================================================
`timescale 1ns/1ps

module fft8_top #(
    parameter W = 16
)(
    input                       clk,
    input                       rst_n,
    input                       valid_in,
    input  signed [8*W-1:0]     x_re_flat,
    input  signed [8*W-1:0]     x_im_flat,

    output reg signed [8*W-1:0] X_re_flat,
    output reg signed [8*W-1:0] X_im_flat,
    output reg                  valid_out
);

    // Latch input
    reg                  vi_r;
    reg signed [8*W-1:0] xr_r;
    reg signed [8*W-1:0] xi_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vi_r <= 1'b0;
            xr_r <= {(8*W){1'b0}};
            xi_r <= {(8*W){1'b0}};
        end else begin
            vi_r <= valid_in;
            xr_r <= x_re_flat;
            xi_r <= x_im_flat;
        end
    end

    wire signed [8*W-1:0] core_X_re;
    wire signed [8*W-1:0] core_X_im;
    wire                  core_v;

    fft8_core #(.W(W)) u_core (
        .clk        (clk),
        .rst_n      (rst_n),
        .valid_in   (vi_r),
        .x_re_flat  (xr_r),
        .x_im_flat  (xi_r),
        .X_re_flat  (core_X_re),
        .X_im_flat  (core_X_im),
        .valid_out  (core_v)
    );

    // Output register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            X_re_flat <= {(8*W){1'b0}};
            X_im_flat <= {(8*W){1'b0}};
        end else begin
            valid_out <= core_v;
            X_re_flat <= core_X_re;
            X_im_flat <= core_X_im;
        end
    end

endmodule
