# =============================================================================
# ModelSim simulation script for tb_cpu_integration_test_top
# Usage: vsim -c -do run_cpu_integration_top.do
# =============================================================================

vlib work

vcom -93 ../../rtl/common/gb_types_pkg.vhd
vcom -93 ../../rtl/top/pll_core_sim.vhd
vcom -93 ../../rtl/cpu/alu.vhd
vcom -93 ../../rtl/cpu/registers.vhd
vcom -93 ../../rtl/cpu/decoder.vhd
vcom -93 ../../rtl/cpu/cpu.vhd
vcom -93 ../../rtl/io/seven_segment_mux.vhd
vcom -93 ../../rtl/top/cpu_integration_test_top.vhd
vcom -93 ../../tb/cpu/tb_cpu_integration_test_top.vhd

vsim work.tb_cpu_integration_test_top
run -all
quit -f
