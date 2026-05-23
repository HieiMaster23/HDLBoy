# =============================================================================
# ModelSim simulation script for tb_sdram_test_top
# Usage: vsim -c -do run_sdram_test_top.do
# =============================================================================

vlib work

vcom -93 ../../rtl/memory/sdram_controller.vhd
vcom -93 ../../rtl/top/sdram_test_top.vhd
vcom -93 ../../tb/integration/tb_sdram_test_top.vhd

vsim work.tb_sdram_test_top
run -all
quit -f
