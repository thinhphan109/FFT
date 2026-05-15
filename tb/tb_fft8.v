//==============================================================================
// File         : tb_fft8.v
// Description  : Testbench for 8-point FFT
//                Test vectors:
//                  1) Impulse:  x = [1,0,0,0,0,0,0,0]   -> X = [1,1,1,1,1,1,1,1]/8
//                  2) Constant: x = [0.5,0.5,...,0.5]   -> X = [0.5,0,0,0,0,0,0,0]
//                  3) Sine wave (k=1):                  -> X has peak at bin 1 and 7
//==============================================================================
`timescale 1ns/1ps

module tb_fft8;

    localparam W      = 16;
    localparam CLK_T  = 10;       // 100 MHz
    localparam ONE    = 16'sd32767;
    localparam HALF   = 16'sd16384;

    reg                       clk;
    reg                       rst_n;
    reg                       valid_in;
    reg  signed [8*W-1:0]     x_re_flat;
    reg  signed [8*W-1:0]     x_im_flat;
    wire signed [8*W-1:0]     X_re_flat;
    wire signed [8*W-1:0]     X_im_flat;
    wire                      valid_out;

    integer error_count = 0;

    // ----------------------------------------------------------------------
    // DUT
    // ----------------------------------------------------------------------
    fft8_top #(.W(W)) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .valid_in   (valid_in),
        .x_re_flat  (x_re_flat),
        .x_im_flat  (x_im_flat),
        .X_re_flat  (X_re_flat),
        .X_im_flat  (X_im_flat),
        .valid_out  (valid_out)
    );

    // ----------------------------------------------------------------------
    // Clock
    // ----------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_T/2) clk = ~clk;

    // ----------------------------------------------------------------------
    // Helpers
    // ----------------------------------------------------------------------
    task pack_input(
        input signed [W-1:0] r0, input signed [W-1:0] r1,
        input signed [W-1:0] r2, input signed [W-1:0] r3,
        input signed [W-1:0] r4, input signed [W-1:0] r5,
        input signed [W-1:0] r6, input signed [W-1:0] r7,
        input signed [W-1:0] i0, input signed [W-1:0] i1,
        input signed [W-1:0] i2, input signed [W-1:0] i3,
        input signed [W-1:0] i4, input signed [W-1:0] i5,
        input signed [W-1:0] i6, input signed [W-1:0] i7
    );
        begin
            x_re_flat = {r7, r6, r5, r4, r3, r2, r1, r0};
            x_im_flat = {i7, i6, i5, i4, i3, i2, i1, i0};
        end
    endtask

    task drive_pulse;
        begin
            @(posedge clk);
            valid_in <= 1'b1;
            @(posedge clk);
            valid_in <= 1'b0;
        end
    endtask

    task wait_valid;
        begin
            @(posedge valid_out);
            @(negedge clk);
        end
    endtask

    function signed [W-1:0] sample_re(input integer idx);
        sample_re = X_re_flat[idx*W +: W];
    endfunction

    function signed [W-1:0] sample_im(input integer idx);
        sample_im = X_im_flat[idx*W +: W];
    endfunction

    function automatic [W-1:0] abs16(input signed [W-1:0] v);
        abs16 = v[W-1] ? -v : v;
    endfunction

    task print_output(input [127:0] tag);
        integer i;
        begin
            $display("[%0t] === %0s ===", $time, tag);
            for (i = 0; i < 8; i = i + 1) begin
                $display("  X[%0d] = (%6d, %6d)  | mag^2 ~ %0d",
                         i, sample_re(i), sample_im(i),
                         (sample_re(i)*sample_re(i) + sample_im(i)*sample_im(i)) >>> 15);
            end
        end
    endtask

    // Tolerance check (within +/- tol LSBs)
    task check_close(input signed [W-1:0] got,
                     input signed [W-1:0] expected,
                     input integer        tol,
                     input [255:0]        msg);
        integer diff;
        begin
            diff = got - expected;
            if (diff < 0) diff = -diff;
            if (diff > tol) begin
                $display("  FAIL %0s : got=%6d expected=%6d (diff=%0d > tol=%0d)",
                         msg, got, expected, diff, tol);
                error_count = error_count + 1;
            end
        end
    endtask

    // ----------------------------------------------------------------------
    // Stimulus
    // ----------------------------------------------------------------------
    integer k;
    integer expected_const;
    initial begin
        rst_n     = 0;
        valid_in  = 0;
        x_re_flat = 0;
        x_im_flat = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // -------------------------------------------------------------
        // Test 1: Impulse  x = [1, 0, 0, 0, 0, 0, 0, 0]  (1.0 Q1.15)
        // Expected: X[k] = 1/N for all k = 32767/8 ~ 4095
        // -------------------------------------------------------------
        pack_input(ONE, 0, 0, 0, 0, 0, 0, 0,
                   0,   0, 0, 0, 0, 0, 0, 0);
        drive_pulse();
        wait_valid();
        print_output("Test 1: Impulse");

        for (k = 0; k < 8; k = k + 1) begin
            check_close(sample_re(k), 16'sd4095, 32, "T1 real");
            check_close(sample_im(k), 16'sd0,    32, "T1 imag");
        end

        // -------------------------------------------------------------
        // Test 2: Constant 0.5  -> DC bin only
        // X[0] = 0.5 (= 16384), X[k>=1] = 0
        // -------------------------------------------------------------
        pack_input(HALF, HALF, HALF, HALF, HALF, HALF, HALF, HALF,
                   0,    0,    0,    0,    0,    0,    0,    0);
        drive_pulse();
        wait_valid();
        print_output("Test 2: Constant 0.5");

        check_close(sample_re(0), 16'sd16383, 32, "T2 X[0] real");
        check_close(sample_im(0), 16'sd0,     32, "T2 X[0] imag");
        for (k = 1; k < 8; k = k + 1) begin
            check_close(sample_re(k), 16'sd0, 32, "T2 X[k>=1] real");
            check_close(sample_im(k), 16'sd0, 32, "T2 X[k>=1] imag");
        end

        // -------------------------------------------------------------
        // Test 3: Cosine at frequency bin 1
        //   x[n] = 0.5 * cos(2*pi*n/8)
        //   Pre-computed Q1.15 (0.5 * cos(2*pi*n/8)):
        //     n=0:  16384
        //     n=1:  11585
        //     n=2:      0
        //     n=3: -11585
        //     n=4: -16384
        //     n=5: -11585
        //     n=6:      0
        //     n=7:  11585
        //   Expected: peak at bin 1 and bin 7 (real ~ 0.25/2 = 16384)
        //             others ~ 0
        // -------------------------------------------------------------
        pack_input( 16'sd16384,  16'sd11585,  16'sd0,     -16'sd11585,
                   -16'sd16384, -16'sd11585,  16'sd0,      16'sd11585,
                    16'sd0,      16'sd0,      16'sd0,      16'sd0,
                    16'sd0,      16'sd0,      16'sd0,      16'sd0);
        drive_pulse();
        wait_valid();
        print_output("Test 3: Cosine bin=1");

        // bins 1 and 7 should have substantial real part, others near zero
        if (abs16(sample_re(1)) < 16'sd6000) begin
            $display("  FAIL T3: bin 1 magnitude too small");
            error_count = error_count + 1;
        end
        if (abs16(sample_re(7)) < 16'sd6000) begin
            $display("  FAIL T3: bin 7 magnitude too small");
            error_count = error_count + 1;
        end
        for (k = 0; k < 8; k = k + 1) begin
            if (k != 1 && k != 7) begin
                if (abs16(sample_re(k)) > 16'sd200 || abs16(sample_im(k)) > 16'sd200) begin
                    $display("  WARN T3 bin %0d: leakage > 200", k);
                end
            end
        end

        // -------------------------------------------------------------
        // Summary
        // -------------------------------------------------------------
        #50;
        $display("");
        $display("=========================================");
        if (error_count == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  TESTS FAILED: %0d errors", error_count);
        $display("=========================================");
        $finish;
    end

    // VCD dump
    initial begin
        $dumpfile("fft8.vcd");
        $dumpvars(0, tb_fft8);
    end

    initial begin
        #20000;
        $display("ERROR: timeout");
        $finish;
    end

endmodule
