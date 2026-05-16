# =============================================================================
# ModelSim simulation script for tb_ppu_background_renderer
# Usage: vsim -c -do run_ppu_background_renderer.do
# =============================================================================

vlib work

vcom -93 ../../rtl/ppu/ppu_background_renderer.vhd
vcom -93 ../../tb/ppu/tb_ppu_background_renderer.vhd

vsim work.tb_ppu_background_renderer
run -all
quit -f
