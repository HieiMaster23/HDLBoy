# =============================================================================
# ModelSim simulation script for tb_blink_led
# Usage: vsim -do run_blink_led.do
# =============================================================================

# Create work library
vlib work

# Compile source and testbench
vcom -93 ../../rtl/top/blink_led.vhd
vcom -93 ../../tb/io/tb_blink_led.vhd

# Load simulation
vsim work.tb_blink_led

# Add waves
add wave -divider "Clock & Reset"
add wave sim:/tb_blink_led/clk_50mhz
add wave sim:/tb_blink_led/reset_n

add wave -divider "Inputs"
add wave sim:/tb_blink_led/key_n

add wave -divider "Outputs"
add wave sim:/tb_blink_led/led

add wave -divider "Internal"
add wave sim:/tb_blink_led/u_dut/counter
add wave sim:/tb_blink_led/u_dut/reset

# Run simulation
run -all
