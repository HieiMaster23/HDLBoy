# =============================================================================
# ModelSim simulation script for tb_ppu_background_demo_top
# Usage: vsim -c -do run_ppu_background_demo_top.do
# =============================================================================

vlib work

vcom -93 ../../rtl/common/gb_types_pkg.vhd
vcom -93 ../../rtl/top/pll_core_sim.vhd
vcom -93 ../../rtl/io/timer.vhd
vcom -93 ../../rtl/video/vga_controller.vhd
vcom -93 ../../rtl/video/vga_pixel_pipeline.vhd
vcom -93 ../../rtl/memory/framebuffer.vhd
vcom -93 ../../rtl/memory/vram.vhd
vcom -93 ../../rtl/memory/bus_controller.vhd
vcom -93 ../../rtl/ppu/ppu_demo_loader.vhd
vcom -93 ../../rtl/ppu/ppu_background_renderer.vhd
vcom -93 ../../rtl/top/ppu_background_demo_top.vhd
vcom -93 ../../tb/integration/tb_ppu_background_demo_top.vhd

vsim work.tb_ppu_background_demo_top
run -all
quit -f
