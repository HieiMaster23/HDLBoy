# Game Boy FPGA Core Architecture

This project is a hardware reimplementation of the Nintendo Game Boy DMG-01
for the Altera Cyclone IV EP4CE6E22C8N FPGA on the OMDAZZ RZ-EasyFPGA A2.2
board. The design is written in synthesizable VHDL-1993 and is organized so
each subsystem can be simulated independently before top-level integration.

## Current Architecture

The current repository contains the M0 infrastructure, validated M1/M2 video
building blocks, the current M3 CPU core, the first M4-style memory map, and an
initial shared M6 timer block:

- `rtl/top/blink_led.vhd`: M0 hardware sanity test for clock, reset, keys, and LEDs.
- `rtl/top/pll_core.vhd`: Quartus ALTPLL wrapper for 50 MHz input clock.
- `rtl/video/vga_controller.vhd`: 640x480 at 60 Hz timing generator.
- `rtl/video/vga_color_bar.vhd`: simple color bar generator for M1 hardware testing.
- `rtl/memory/framebuffer.vhd`: 160x144x2-bit dual-port framebuffer.
- `rtl/memory/vram.vhd`: 8 KiB dual-port VRAM used by CPU writes and PPU reads.
- `rtl/memory/sdram_controller.vhd`: first isolated SDRAM controller slice for
  future ROM loading and cartridge-backed reads.
- `rtl/memory/sdram_rom_loader.vhd`: byte-stream ROM loader core that packs
  incoming bytes into little-endian 16-bit SDRAM write commands.
- `rtl/memory/sdram_rom_reader.vhd`: ROM-only byte reader that translates CPU
  cartridge addresses into SDRAM word reads with wait-state support.
- `rtl/memory/cpu_video_smoke_rom.vhd`: standalone ROM image for the legacy
  CPU-to-framebuffer smoke program.
- `rtl/memory/cpu_ppu_background_demo_rom.vhd`: standalone ROM image for the
  CPU-authored background integration program.
- `rtl/video/vga_pixel_pipeline.vhd`: 3x upscaling and palette mapping.
- `rtl/video/test_pattern_writer.vhd`: M2 framebuffer fill pattern.
- `rtl/top/framebuffer_test_top.vhd`: M2 integration test top.
- `rtl/cpu/cpu.vhd`: incremental multi-cycle Sharp LR35902 CPU core.
- `rtl/top/cpu_integration_test_top.vhd`: CPU-only hardware integration test
  with LEDs and seven-segment pass/fail output.
- `rtl/top/cpu_video_smoke_top.vhd`: CPU-to-framebuffer smoke test that writes
  visible pixels into the VGA framebuffer.
- `rtl/ppu/ppu_background_renderer.vhd`: first background-only PPU slice that
  reads tile data and tile map entries from VRAM and fills the framebuffer.
- `rtl/ppu/ppu_demo_loader.vhd`: small VRAM initializer used only by the first
  PPU visual demo.
- `rtl/top/ppu_background_demo_top.vhd`: current visual integration top for the
  first VRAM-to-PPU-to-framebuffer path.
- `rtl/top/cpu_ppu_background_demo_top.vhd`: first combined CPU/PPU visual top;
  the CPU writes tile data plus tile-map contents into VRAM before the PPU
  renders the framebuffer.
- `rtl/memory/bus_controller.vhd`: current CPU-facing memory map for smoke ROM,
  experimental framebuffer writes, full 8 KiB WRAM with echo mirror, HRAM,
  IF/IE registers, basic I/O stubs, debug I/O, and the memory-ready contract.
- `rtl/io/timer.vhd`: initial shared DMG-style timer block with DIV/TIMA/TMA/TAC,
  TAC-selected divider edges, delayed TIMA reload, and timer interrupt output.
- `rtl/io/ps2_keyboard_joypad.vhd`: compact PS/2 Set-2 make/break decoder
  that maps keyboard keys to the Game Boy joypad button signals.
- `rtl/io/virtual_jtag_rom_stream_core.vhd`: simulatable Virtual JTAG protocol
  and CDC core for streaming ROM bytes into the SDRAM loader.
- `rtl/io/virtual_jtag_rom_stream.vhd`: thin Altera `sld_virtual_jtag` wrapper
  around the ROM stream protocol core.
- `scripts/load_rom_virtual_jtag.tcl`: host-side Quartus STP script that reads
  a `.gb` file and streams it through the Virtual JTAG DATA/CONTROL/STATUS
  protocol.
- `rtl/top/sdram_test_top.vhd`: dedicated physical SDRAM bring-up top with a
  deterministic write/read checker and LED status outputs.
- `rtl/top/sdram_jtag_loader_top.vhd`: dedicated physical loader top combining
  Virtual JTAG, `sdram_rom_loader`, and `sdram_controller`.
- `rtl/top/sdram_cpu_rom_top.vhd`: dedicated load-then-execute top that loads
  ROM bytes into SDRAM through Virtual JTAG, then releases the CPU to fetch
  cartridge ROM bytes through `sdram_rom_reader`.

## Clock Domains

- `clk_50mhz`: board oscillator input.
- `clk_vga`: PLL output for VGA pixel timing.
- `clk_cpu`: PLL output intended for the Game Boy CPU domain.

The framebuffer is the first intentional clock-domain boundary. Port A is
written from the Game Boy-side clock domain; Port B is read by the VGA
pipeline. The M2 test top drives both ports with `clk_vga` for a simple static
image demo. The CPU video smoke top writes it from `clk_cpu`, and the current
PPU demo top now writes it from the background renderer while VGA continues to
read it from `clk_vga`.

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

## Current Integration State

The current M4 bus slice provides the first CPU-facing memory map. It includes
real 8 KiB VRAM at `0x8000..0x9FFF`, full 8 KiB WRAM at `0xC000..0xDFFF`,
mirrored through the implemented echo range at `0xE000..0xFDFF`, plus HRAM and
the current I/O stubs. The CPU bus now has a `mem_ready` handshake so RAM-backed
regions can use registered reads without forcing large combinational register
arrays onto the EP4CE6 fabric.

The test-program boundary is now also explicit. `bus_controller` maps the ROM
address range but no longer owns the embedded program contents. Small bring-up
tops instantiate their own ROM module and feed the resulting byte plus
`rom_ready = '1'` into the bus. The same bus contract now also supports a
wait-stated ROM source, which is the boundary needed for the SDRAM-backed
cartridge path.

WRAM, VRAM, and HRAM are inferred by Quartus as M9K-backed `altsyncram` blocks.
HRAM was originally kept as local bus-controller logic, but that structure
retained a large register footprint. It is now isolated in a dedicated
synchronous single-port memory module so the same CPU ready-state path can keep
RAM-backed reads compatible with the bus contract.

The CPU is now validated against all individual Blargg `cpu_instrs` ROMs,
`instr_timing.gb`, the `mem_timing`/`mem_timing-2` individual plus aggregate
ROMs, `interrupt_time.gb`, and `halt_bug.gb` through the ROM runner. That result
proves broad behavioral coverage plus the first timing contracts for instruction
duration, memory access placement, interrupt-entry latency, and the HALT case
covered by Blargg. The immediate architectural work is therefore to checkpoint
this phase and begin the first real PPU slice.

The first real PPU slice is now present. It is intentionally narrow:
`ppu_background_renderer` reads unsigned tile data plus the background tile map,
applies `SCX`/`SCY` background offsets, advances through explicit visible
scanline boundaries, and the existing framebuffer/VGA path displays the result.
The isolated demo top still exists, but the current system-level visual top now
lets the CPU populate VRAM and scroll registers before the renderer starts. This
is not yet the final dot-accurate DMG PPU. It is the first verified interconnect
where the CPU authors video memory, controls a visible PPU behavior, and the PPU
has an observable line progression point. The bus now exposes a minimal `LY`
readback from that line signal and a `STAT` value with writable interrupt-select
bits, coincidence status, and a deterministic initial PPU mode field. The mode
source is now owned by the renderer rather than inferred by the bus: Mode 2 is
reported at visible-line start, Mode 3 while background pixels are produced,
Mode 0 at visible-line end, and Mode 1 during the initial VBlank line range.
That mode source now also drives the first interrupt-visible PPU behavior:
VBlank entry requests IF bit 0, and enabled STAT conditions request IF bit 1 for
Mode 0, Mode 1, Mode 2, and `LY=LYC`.

That combined path has been confirmed on the real OMDAZZ board. The observed
image was the expected centered Game Boy area with a first tile row alternating
between white and checkerboard tiles, proving the complete live chain:
`CPU -> bus_controller -> VRAM -> PPU -> framebuffer -> VGA`. Since that
hardware checkpoint, the PPU path has also gained continuous frame looping,
initial LCDC/BGP/OBP handling, OAM storage, OAM scan, first 10-candidate sprite
composition, and an initial WRAM/Echo-backed OAM DMA path triggered by writes to
`0xFF46`. The bus now also implements the real `0xFF00` JOYP register contract:
CPU-written select bits choose the action and direction groups, reads return
active-low button state, and selected press edges request IF bit 4. The current
hardware top maps the four verified `key_n` pins to A, B, Select, and Start,
and also exposes the first PS/2 keyboard input path: `D/A/W/S` map to
Right/Left/Up/Down, `J/K` map to A/B, Space maps to Select, and Enter maps to
Start. PS/2 inputs are synchronized into the CPU domain before they reach the
JOYP register path.
The PPU path now also has initial Window rendering: `WY/WX` are exposed by the
bus, `LCDC(5)` enables Window pixels, `LCDC(6)` selects the Window tile map, and
the renderer switches from scroll-based background coordinates to
`screen_x + 7 - WX` / `screen_y - WY` Window coordinates when the pixel is
inside the Window region. Sprite composition now keeps the 10-candidate
scanline limit and applies the DMG OBJ priority rule: lower X coordinate wins,
with lower OAM order preserved when X coordinates are equal.

The next architectural steps are:

1. Program the dedicated SDRAM hardware test top and confirm init/pass/refresh
   behavior on the physical board.
2. Program `sdram_jtag_loader_top`, then run
   `quartus_stp -t scripts/load_rom_virtual_jtag.tcl <rom.gb>` to validate the
   USB-Blaster-to-SDRAM loading path on hardware.
3. Program `sdram_cpu_rom_top`, load a minimal no-MBC test ROM, and confirm
   that the CPU executes code fetched from SDRAM.
4. Extend OAM DMA source coverage later when the ROM/cartridge/SDRAM path is
   defined.
5. Revisit exact PPU FIFO/fetch timing only when a target ROM exposes a concrete
   compatibility issue.
6. Grow the SDRAM path from the hardware test top into a ROM-only cartridge
   mapper.

The design should continue to keep module-level testbenches close to each RTL
block and add integration testbenches only when a cross-module contract exists.
