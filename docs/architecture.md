# Game Boy FPGA Core Architecture

This project is a hardware reimplementation of the Nintendo Game Boy DMG-01
for the Altera Cyclone IV EP4CE6E22C8N FPGA on the OMDAZZ RZ-EasyFPGA A2.2
board. The design is written in synthesizable VHDL-1993 and is organized so
each subsystem can be simulated independently before top-level integration.

## Current Architecture

The current repository contains the M0 infrastructure, early M1/M2 video
building blocks, and the first M3 CPU-to-video integration harness:

- `rtl/top/blink_led.vhd`: M0 hardware sanity test for clock, reset, keys, and LEDs.
- `rtl/top/pll_core.vhd`: Quartus ALTPLL wrapper for 50 MHz input clock.
- `rtl/video/vga_controller.vhd`: 640x480 at 60 Hz timing generator.
- `rtl/video/vga_color_bar.vhd`: simple color bar generator for M1 hardware testing.
- `rtl/memory/framebuffer.vhd`: 160x144x2-bit dual-port framebuffer.
- `rtl/video/vga_pixel_pipeline.vhd`: 3x upscaling and palette mapping.
- `rtl/video/test_pattern_writer.vhd`: M2 framebuffer fill pattern.
- `rtl/top/framebuffer_test_top.vhd`: M2 integration test top.
- `rtl/cpu/cpu.vhd`: incremental multi-cycle Sharp LR35902 CPU subset.
- `rtl/top/cpu_integration_test_top.vhd`: CPU-only hardware integration test
  with LEDs and seven-segment pass/fail output.
- `rtl/top/cpu_video_smoke_top.vhd`: CPU-to-framebuffer smoke test that writes
  visible pixels into the VGA framebuffer.
- `rtl/memory/bus_controller.vhd`: first CPU-facing memory map for smoke ROM,
  experimental framebuffer writes, debug I/O, and future M4 expansion.

## Clock Domains

- `clk_50mhz`: board oscillator input.
- `clk_vga`: PLL output for VGA pixel timing.
- `clk_cpu`: PLL output intended for the Game Boy CPU domain.

The framebuffer is the first intentional clock-domain boundary. Port A is
intended for the future PPU/CPU-side writer; Port B is read by the VGA pipeline.
The M2 test top drives both ports with `clk_vga` for a simple static image
demo. The current CPU video smoke top writes the framebuffer from `clk_cpu` and
reads it from `clk_vga`, exercising the intended dual-clock boundary on real
hardware.

## Video Path

The video path is:

1. `vga_controller` generates sync signals, visible flag, and pixel coordinates.
2. `vga_pixel_pipeline` maps the centered 480x432 region to 160x144 framebuffer
   coordinates with 3x integer scaling.
3. `framebuffer` returns a 2-bit Game Boy pixel value.
4. `vga_pixel_pipeline` maps the 2-bit value to RGB intensity.

The Game Boy image is centered in VGA visible space with black borders:

- Horizontal offset: 80 pixels.
- Vertical offset: 24 pixels.
- Display area: 480x432 pixels.

## Near-Term Integration

The next architectural step is to extract the temporary top-level memory decode
into a CPU-facing memory/bus structure:

- Memory map decoder for ROM, experimental VRAM/framebuffer, WRAM, OAM, I/O,
  HRAM, IF, and IE.
- Timer, interrupt controller, and joypad register.
- PPU write path into the framebuffer.

The design should continue to keep module-level testbenches close to each RTL
block and add integration testbenches only when a cross-module contract exists.
