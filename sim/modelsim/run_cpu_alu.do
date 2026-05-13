# =============================================================================
# ModelSim simulation script for tb_alu
# Usage: vsim -c -do run_cpu_alu.do
# =============================================================================

vlib work

vcom -93 ../../rtl/common/gb_types_pkg.vhd
vcom -93 ../../rtl/cpu/alu.vhd
vcom -93 ../../tb/cpu/tb_alu.vhd

vsim work.tb_alu
run -all
quit -f
