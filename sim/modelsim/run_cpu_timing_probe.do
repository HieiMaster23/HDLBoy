# =============================================================================
# ModelSim script for the CPU timing probe
# Usage from sim/modelsim:
#   vsim -c -do run_cpu_timing_probe.do
# =============================================================================

vlib work

vcom -93 ../../rtl/common/gb_types_pkg.vhd
vcom -93 ../../rtl/cpu/alu.vhd
vcom -93 ../../rtl/cpu/registers.vhd
vcom -93 ../../rtl/cpu/decoder.vhd
vcom -93 ../../rtl/cpu/cpu.vhd
vcom -93 ../../tb/cpu/tb_cpu_timing_probe.vhd

vsim -c work.tb_cpu_timing_probe
run -all
quit -f
