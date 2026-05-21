# =============================================================================
# ModelSim simulation script for tb_bus_controller
# Usage: vsim -c -do run_bus_controller.do
# =============================================================================

vlib work

vcom -93 ../../rtl/io/timer.vhd
vcom -93 ../../rtl/memory/vram.vhd
vcom -93 ../../rtl/memory/hram.vhd
vcom -93 ../../rtl/memory/cpu_video_smoke_rom.vhd
vcom -93 ../../rtl/memory/bus_controller.vhd
vcom -93 ../../tb/memory/tb_bus_controller.vhd

vsim work.tb_bus_controller
run -all
quit -f
