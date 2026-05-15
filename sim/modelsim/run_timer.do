# =============================================================================
# ModelSim simulation script for tb_timer
# Usage: vsim -c -do run_timer.do
# =============================================================================

vlib work

vcom -93 ../../rtl/io/timer.vhd
vcom -93 ../../tb/io/tb_timer.vhd

vsim work.tb_timer
run -all
quit -f
