# =============================================================================
# ModelSim script for Blargg cpu_instrs/individual/01-special.gb
# Usage from sim/modelsim:
#   vsim -c -do run_cpu_blargg_01.do
# =============================================================================

vlib work

vcom -93 ../../rtl/common/gb_types_pkg.vhd
vcom -93 ../../rtl/cpu/alu.vhd
vcom -93 ../../rtl/cpu/registers.vhd
vcom -93 ../../rtl/cpu/decoder.vhd
vcom -93 ../../rtl/cpu/cpu.vhd
vcom -93 ../../tb/cpu/tb_cpu_rom_runner.vhd

vsim -c -gG_ROM_PATH=../../gb-test-roms-master/cpu_instrs/individual/01-special.gb -gG_TIMEOUT_CYCLES=50000000 work.tb_cpu_rom_runner
run -all
quit -f
