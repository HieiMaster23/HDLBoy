# =============================================================================
# ModelSim simulation script for tb_decoder
# Usage: vsim -c -do run_cpu_decoder.do
# =============================================================================

vlib work

vcom -93 ../../rtl/common/gb_types_pkg.vhd
vcom -93 ../../rtl/cpu/decoder.vhd
vcom -93 ../../tb/cpu/tb_decoder.vhd

vsim work.tb_decoder
run -all
quit -f
