# =============================================================================
# ModelSim simulation script for tb_vga_pixel_pipeline
# Usage: vsim -do run_pixel_pipeline.do
# =============================================================================

# Create work library
vlib work

# Compile source and testbench
vcom -93 ../../rtl/video/vga_pixel_pipeline.vhd
vcom -93 ../../tb/video/tb_vga_pixel_pipeline.vhd

# Load simulation
vsim work.tb_vga_pixel_pipeline

# Add waves
add wave -divider "Clock & Reset"
add wave sim:/tb_vga_pixel_pipeline/clk_vga
add wave sim:/tb_vga_pixel_pipeline/reset

add wave -divider "VGA Coordinates"
add wave -radix unsigned sim:/tb_vga_pixel_pipeline/pixel_x
add wave -radix unsigned sim:/tb_vga_pixel_pipeline/pixel_y
add wave sim:/tb_vga_pixel_pipeline/visible

add wave -divider "Framebuffer Interface"
add wave -radix unsigned sim:/tb_vga_pixel_pipeline/fb_addr
add wave -radix binary sim:/tb_vga_pixel_pipeline/fb_data

add wave -divider "RGB Output"
add wave -radix binary sim:/tb_vga_pixel_pipeline/vga_r
add wave -radix binary sim:/tb_vga_pixel_pipeline/vga_g
add wave -radix binary sim:/tb_vga_pixel_pipeline/vga_b

add wave -divider "Pipeline Internals"
add wave sim:/tb_vga_pixel_pipeline/u_dut/in_game_area_s1
add wave sim:/tb_vga_pixel_pipeline/u_dut/in_game_area_s2
add wave sim:/tb_vga_pixel_pipeline/u_dut/visible_s1
add wave sim:/tb_vga_pixel_pipeline/u_dut/visible_s2

# Run simulation
run -all
