# =============================================================================
# ModelSim simulation script for tb_bus_controller
# Usage: vsim -c -do run_bus_controller.do
# =============================================================================

vlib work

vcom -93 ../../rtl/memory/bus_controller.vhd
vcom -93 ../../tb/memory/tb_bus_controller.vhd

vsim work.tb_bus_controller
run -all
quit -f
