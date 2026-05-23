# =============================================================================
# ModelSim simulation script for tb_sdram_rom_loader
# Usage: vsim -c -do run_sdram_rom_loader.do
# =============================================================================

vlib work

vcom -93 ../../rtl/memory/sdram_rom_loader.vhd
vcom -93 ../../tb/memory/tb_sdram_rom_loader.vhd

vsim work.tb_sdram_rom_loader
run -all
quit -f
