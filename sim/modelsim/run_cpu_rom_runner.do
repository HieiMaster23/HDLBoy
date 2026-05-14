# =============================================================================
# ModelSim simulation script for the CPU ROM runner bridge test
# Usage: vsim -c -do run_cpu_rom_runner.do
# =============================================================================

vlib work

vcom -93 ../../rtl/common/gb_types_pkg.vhd
vcom -93 ../../rtl/cpu/alu.vhd
vcom -93 ../../rtl/cpu/registers.vhd
vcom -93 ../../rtl/cpu/decoder.vhd
vcom -93 ../../rtl/cpu/cpu.vhd
vcom -93 ../../tb/cpu/tb_cpu_rom_runner.vhd

vsim work.tb_cpu_rom_runner
run -all

