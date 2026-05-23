# =============================================================================
# ModelSim simulation script for tb_ps2_keyboard_joypad
# Usage: vsim -c -do run_ps2_keyboard_joypad.do
# =============================================================================

vlib work

vcom -93 ../../rtl/io/ps2_keyboard_joypad.vhd
vcom -93 ../../tb/io/tb_ps2_keyboard_joypad.vhd

vsim work.tb_ps2_keyboard_joypad
run -all
quit -f
