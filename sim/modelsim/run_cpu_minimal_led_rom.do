# =============================================================================
# ModelSim simulation script for tb_cpu_minimal_led_rom
# Usage: vsim -c -do run_cpu_minimal_led_rom.do
# =============================================================================

vlib work

vcom -93 ../../rtl/common/gb_types_pkg.vhd
vcom -93 ../../rtl/cpu/alu.vhd
vcom -93 ../../rtl/cpu/registers.vhd
vcom -93 ../../rtl/cpu/decoder.vhd
vcom -93 ../../rtl/cpu/cpu.vhd
vcom -93 ../../tb/cpu/tb_cpu_minimal_led_rom.vhd

vsim work.tb_cpu_minimal_led_rom
run -all
quit -f
