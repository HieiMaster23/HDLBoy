# =============================================================================
# ModelSim simulation script for tb_vram
# Usage: vsim -c -do run_vram.do
# =============================================================================

vlib work

vcom -93 ../../rtl/memory/vram.vhd
vcom -93 ../../tb/memory/tb_vram.vhd

vsim work.tb_vram
run -all
quit -f
