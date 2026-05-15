# =============================================================================
# ModelSim simulation script for the first M3 CPU subset
# Usage: vsim -c -do run_cpu_all.do
# =============================================================================

vlib work

vcom -93 ../../rtl/common/gb_types_pkg.vhd
vcom -93 ../../rtl/cpu/alu.vhd
vcom -93 ../../rtl/cpu/registers.vhd
vcom -93 ../../rtl/cpu/decoder.vhd
vcom -93 ../../rtl/cpu/cpu.vhd
vcom -93 ../../rtl/io/timer.vhd
vcom -93 ../../tb/cpu/tb_alu.vhd
vcom -93 ../../tb/cpu/tb_registers.vhd
vcom -93 ../../tb/cpu/tb_decoder.vhd
vcom -93 ../../tb/cpu/tb_cpu_smoke.vhd
vcom -93 ../../tb/cpu/tb_cpu_rom_runner.vhd

vsim work.tb_alu
run -all
quit -sim

vsim work.tb_registers
run -all
quit -sim

vsim work.tb_decoder
run -all
quit -sim

vsim work.tb_cpu_smoke
run -all
quit -sim

vsim work.tb_cpu_rom_runner
run -all
quit -f
