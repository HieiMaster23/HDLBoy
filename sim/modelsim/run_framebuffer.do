# =============================================================================
# ModelSim simulation script for tb_framebuffer
# Usage: vsim -do run_framebuffer.do
# =============================================================================

# Create work library
vlib work

# Compile source and testbench
vcom -93 ../../rtl/memory/framebuffer.vhd
vcom -93 ../../tb/memory/tb_framebuffer.vhd

# Load simulation
vsim work.tb_framebuffer

# Add waves
add wave -divider "Port A (Write / CPU domain)"
add wave sim:/tb_framebuffer/clk_a
add wave sim:/tb_framebuffer/we_a
add wave -radix unsigned sim:/tb_framebuffer/addr_a
add wave -radix binary sim:/tb_framebuffer/data_a

add wave -divider "Port B (Read / VGA domain)"
add wave sim:/tb_framebuffer/clk_b
add wave -radix unsigned sim:/tb_framebuffer/addr_b
add wave -radix binary sim:/tb_framebuffer/data_b

# Run simulation
run -all
