//==============================================================================
// File         : twiddle_rom.v
// Description  : Twiddle factor ROM for 8-point FFT (Q1.15 fixed-point)
//
//                W_N^k = exp(-j*2*pi*k/N)
//
//                W8^0 =  1.0      + j*0.0    -> ( 32767,      0)
//                W8^1 =  0.7071   - j*0.7071 -> ( 23170, -23170)
//                W8^2 =  0.0      - j*1.0    -> (     0, -32768)
//                W8^3 = -0.7071   - j*0.7071 -> (-23170, -23170)
//
//                Note: 1.0 is approximated as 32767 in Q1.15 because the
//                      maximum representable value is (2^15 - 1) / 2^15.
//                      -1.0 IS exactly representable as -32768 (0x8000).
//==============================================================================
`timescale 1ns/1ps

module twiddle_rom #(
    parameter W = 16
)(
    input  [1:0]            k,        // 0..3
    output reg signed [W-1:0] w_re,
    output reg signed [W-1:0] w_im
);

    always @(*) begin
        case (k)
            2'd0: begin w_re =  16'sd32767; w_im =  16'sd0;     end //  1, 0
            2'd1: begin w_re =  16'sd23170; w_im = -16'sd23170; end //  0.707,-0.707
            2'd2: begin w_re =  16'sd0;     w_im = -16'sd32768; end //  0, -1
            2'd3: begin w_re = -16'sd23170; w_im = -16'sd23170; end // -0.707,-0.707
            default: begin w_re = 16'sd0; w_im = 16'sd0; end
        endcase
    end

endmodule
