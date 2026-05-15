# =============================================================================
# ModelSim script for Blargg cpu_instrs/cpu_instrs.gb aggregate ROM
# Usage from sim/modelsim:
#   vsim -c -do run_cpu_blargg_all.do
# =============================================================================

vlib work

vcom -93 ../../rtl/common/gb_types_pkg.vhd
vcom -93 ../../rtl/cpu/alu.vhd
vcom -93 ../../rtl/cpu/registers.vhd
vcom -93 ../../rtl/cpu/decoder.vhd
vcom -93 ../../rtl/cpu/cpu.vhd
vcom -93 ../../rtl/io/timer.vhd
vcom -93 ../../tb/cpu/tb_cpu_rom_runner.vhd

vsim -c -gG_ROM_PATH=../../gb-test-roms-master/cpu_instrs/cpu_instrs.gb -gG_TIMEOUT_CYCLES=250000000 -gG_VERBOSE_SERIAL=false work.tb_cpu_rom_runner
run -all
quit -f
