# =============================================================================
# ModelSim simulation script for framebuffer_test_top (M2 integration)
# Usage: vsim -do run_framebuffer_top.do
# =============================================================================
# Runs the full M2 integration: PLL (sim) + VGA controller + test pattern
# writer + framebuffer + pixel pipeline.
#
# The test pattern writer fills the framebuffer in 23,040 cycles (~0.9 ms at
# 25 MHz), then VGA output starts displaying. We run for 2 full VGA frames
# (~33.4 ms) to see the output stabilize.
# =============================================================================

# Create work library
vlib work

# Compile all sources in dependency order
vcom -93 ../../rtl/common/gb_types_pkg.vhd
vcom -93 ../../rtl/video/vga_controller.vhd
vcom -93 ../../rtl/memory/framebuffer.vhd
vcom -93 ../../rtl/video/vga_pixel_pipeline.vhd
vcom -93 ../../rtl/video/test_pattern_writer.vhd

# PLL simulation stub (passthrough for simulation)
# Create a simple PLL stub entity since the real ALTPLL needs altera_mf library
vcom -93 ../../rtl/top/pll_core_sim.vhd

vcom -93 ../../rtl/top/framebuffer_test_top.vhd

# Load simulation
vsim work.framebuffer_test_top

# Add waves
add wave -divider "Clock & Reset"
add wave sim:/framebuffer_test_top/clk_50mhz
add wave sim:/framebuffer_test_top/reset_n
add wave sim:/framebuffer_test_top/clk_vga
add wave sim:/framebuffer_test_top/pll_locked

add wave -divider "VGA Output"
add wave sim:/framebuffer_test_top/vga_hsync
add wave sim:/framebuffer_test_top/vga_vsync
add wave -radix binary sim:/framebuffer_test_top/vga_r
add wave -radix binary sim:/framebuffer_test_top/vga_g
add wave -radix binary sim:/framebuffer_test_top/vga_b

add wave -divider "Test Pattern Writer"
add wave sim:/framebuffer_test_top/fb_we_a
add wave -radix unsigned sim:/framebuffer_test_top/fb_addr_a
add wave -radix binary sim:/framebuffer_test_top/fb_data_a
add wave sim:/framebuffer_test_top/pattern_done

add wave -divider "Pixel Pipeline"
add wave -radix unsigned sim:/framebuffer_test_top/pixel_x
add wave -radix unsigned sim:/framebuffer_test_top/pixel_y
add wave sim:/framebuffer_test_top/visible
add wave -radix unsigned sim:/framebuffer_test_top/fb_addr_b
add wave -radix binary sim:/framebuffer_test_top/fb_data_b

add wave -divider "LEDs"
add wave sim:/framebuffer_test_top/led

# Run for 2 full VGA frames + pattern write time
# Pattern: ~23040 * 40ns = 0.9ms
# 2 frames: 2 * 16.7ms = 33.4ms
# Total: ~35ms
run 35 ms
