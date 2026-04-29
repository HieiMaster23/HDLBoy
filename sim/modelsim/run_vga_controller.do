# =============================================================================
# ModelSim simulation script for tb_vga_controller
# Usage: vsim -do run_vga_controller.do
# =============================================================================
# NOTE: A full VGA frame (800x525 = 420,000 clocks) at ~40ns period takes
# ~16.7 ms of simulated time. The testbench runs ~2.5 frames, so expect
# ~42 ms total simulation time. This may take a few minutes in ModelSim.
# =============================================================================

# Create work library
vlib work

# Compile source and testbench
vcom -93 ../../rtl/video/vga_controller.vhd
vcom -93 ../../tb/video/tb_vga_controller.vhd

# Load simulation
vsim work.tb_vga_controller

# Add waves — organized by signal group
add wave -divider "Clock & Reset"
add wave sim:/tb_vga_controller/clk_vga
add wave sim:/tb_vga_controller/reset

add wave -divider "Sync Signals"
add wave sim:/tb_vga_controller/hsync
add wave sim:/tb_vga_controller/vsync

add wave -divider "Pixel Position"
add wave -radix unsigned sim:/tb_vga_controller/pixel_x
add wave -radix unsigned sim:/tb_vga_controller/pixel_y

add wave -divider "Blanking"
add wave sim:/tb_vga_controller/visible

add wave -divider "Internal Counters"
add wave -radix unsigned sim:/tb_vga_controller/u_dut/h_count
add wave -radix unsigned sim:/tb_vga_controller/u_dut/v_count

# Run simulation
run -all
