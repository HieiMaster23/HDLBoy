# =============================================================================
# ModelSim simulation script for tb_registers
# Usage: vsim -c -do run_cpu_registers.do
# =============================================================================

vlib work

vcom -93 ../../rtl/common/gb_types_pkg.vhd
vcom -93 ../../rtl/cpu/registers.vhd
vcom -93 ../../tb/cpu/tb_registers.vhd

vsim work.tb_registers
run -all
quit -f
