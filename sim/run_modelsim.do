# ModelSim/Questa simulation script for FFT-8
# Usage: vsim -do run_modelsim.do

if {[file exists work]} {
    vdel -all
}
vlib work

vlog -sv ../rtl/complex_mul.v
vlog -sv ../rtl/butterfly.v
vlog -sv ../rtl/twiddle_rom.v
vlog -sv ../rtl/fft8_core.v
vlog -sv ../rtl/fft8_top.v
vlog -sv ../tb/tb_fft8.v

vsim -voptargs="+acc" tb_fft8

add wave -divider "Top control"
add wave sim:/tb_fft8/clk
add wave sim:/tb_fft8/rst_n
add wave sim:/tb_fft8/valid_in
add wave sim:/tb_fft8/valid_out

add wave -divider "Input samples"
add wave -hex sim:/tb_fft8/x_re_flat
add wave -hex sim:/tb_fft8/x_im_flat

add wave -divider "Output samples"
add wave -hex sim:/tb_fft8/X_re_flat
add wave -hex sim:/tb_fft8/X_im_flat

run -all
wave zoom full
