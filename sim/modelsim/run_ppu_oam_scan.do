# =============================================================================
# ModelSim simulation script for tb_ppu_oam_scan
# Usage: vsim -c -do run_ppu_oam_scan.do
# =============================================================================

vlib work

vcom -93 ../../rtl/ppu/ppu_oam_scan.vhd
vcom -93 ../../tb/ppu/tb_ppu_oam_scan.vhd

vsim work.tb_ppu_oam_scan
run -all
quit -f
