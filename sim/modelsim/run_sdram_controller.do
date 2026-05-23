# =============================================================================
# ModelSim simulation script for tb_sdram_controller
# Usage: vsim -c -do run_sdram_controller.do
# =============================================================================

vlib work

vcom -93 ../../rtl/memory/sdram_controller.vhd
vcom -93 ../../tb/memory/tb_sdram_controller.vhd

vsim work.tb_sdram_controller
run -all
quit -f
