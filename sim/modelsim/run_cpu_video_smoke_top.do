# =============================================================================
# ModelSim simulation script for tb_cpu_video_smoke_top
# Usage: vsim -c -do run_cpu_video_smoke_top.do
# =============================================================================

vlib work

vcom -93 ../../rtl/common/gb_types_pkg.vhd
vcom -93 ../../rtl/top/pll_core_sim.vhd
vcom -93 ../../rtl/cpu/alu.vhd
vcom -93 ../../rtl/cpu/registers.vhd
vcom -93 ../../rtl/cpu/decoder.vhd
vcom -93 ../../rtl/cpu/cpu.vhd
vcom -93 ../../rtl/io/timer.vhd
vcom -93 ../../rtl/io/seven_segment_mux.vhd
vcom -93 ../../rtl/video/vga_controller.vhd
vcom -93 ../../rtl/memory/framebuffer.vhd
vcom -93 ../../rtl/memory/vram.vhd
vcom -93 ../../rtl/memory/hram.vhd
vcom -93 ../../rtl/memory/cpu_video_smoke_rom.vhd
vcom -93 ../../rtl/memory/bus_controller.vhd
vcom -93 ../../rtl/video/vga_pixel_pipeline.vhd
vcom -93 ../../rtl/top/cpu_video_smoke_top.vhd
vcom -93 ../../tb/integration/tb_cpu_video_bus_controller.vhd
vcom -93 ../../tb/integration/tb_cpu_video_smoke_top.vhd

vsim work.tb_cpu_video_bus_controller
run -all
quit -sim

vsim work.tb_cpu_video_smoke_top
run -all
quit -f
