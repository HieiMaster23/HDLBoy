# Game Boy DMG - FPGA Hardware Reimplementation

A hardware reimplementation of the Nintendo Game Boy DMG-01 in synthesizable
VHDL, targeting the Altera Cyclone IV EP4CE6 FPGA on the OMDAZZ RZ-EasyFPGA
A2.2 board.

This is a hardware reimplementation, not a software emulator. The long-term
goal is to rebuild the Game Boy CPU, PPU, timer, memory bus, and I/O as digital
logic that runs directly on the FPGA fabric.

## Target Hardware

| Component | Specification |
| --- | --- |
| FPGA | Altera Cyclone IV EP4CE6 E22C8N |
| Logic elements | 6,272 |
| Block RAM | 276,480 bits, about 33.6 KB |
| PLLs | 2 |
| Board clock | 50 MHz |
| External SDRAM | 64 Mbit, 8 MB |
| Video output | VGA |
| Toolchain | Quartus II 13.0 SP1 and ModelSim-Altera |

## Project Status

| Milestone | Description | Status |
| --- | --- | --- |
| M0 | Infrastructure and environment setup | RTL, simulation, Quartus build, and JTAG programming complete |
| M1 | VGA controller 640x480 at 60 Hz | RTL, simulation, Quartus build, and JTAG programming complete |
| M2 | Framebuffer and pixel pipeline | RTL, simulation, Quartus build, JTAG programming, and VGA-HDMI visual hardware validation complete |
| M3 | CPU core - Sharp LR35902 | Broad multi-cycle subset implemented; all individual Blargg `cpu_instrs`, `instr_timing`, `mem_timing`, `mem_timing-2`, `interrupt_time`, and `halt_bug` ROMs pass |
| M4 | Memory map and bus controller | Initial bus, full WRAM, HRAM, IE/IF, and memory-ready path implemented |
| M5 | PPU | Background, Window, initial sprites, palette lookup, VBlank/STAT, and VGA path implemented for first playable bring-up |
| M6 | Timer, joypad, and I/O | Timer, JOYP register, Joypad interrupt, and PS/2/button input path implemented |
| M7 | SDRAM controller and ROM loading | SDRAM controller, Virtual JTAG ROM loader, and SDRAM ROM reader implemented |
| M8 | Final integration and boot ROM | Initial SDRAM/video integration can run a 32 KiB no-MBC commercial ROM; Tetris title screen validated on hardware |
| M9 | APU | Optional |
| M10 | PS/2 keyboard | Optional |

Current commercial-ROM bring-up Quartus top-level:

```text
sdram_video_rom_top
```

The current bring-up build loads a 32 KiB no-MBC ROM into external SDRAM through
USB-Blaster/Virtual JTAG, releases the CPU after the load completes, fetches
cartridge bytes from SDRAM, and renders through the hardware PPU/framebuffer/VGA
path. On 2026-05-28, this path displayed the Tetris title/menu screen on the
OMDAZZ board. This is an initial first-playable checkpoint, not a full
compatibility claim; the next focus is validating input, gameplay progression,
and longer stability.

## Building

### Prerequisites

- Quartus II 13.0 SP1 with Cyclone IV support.
- ModelSim-Altera bundled with Quartus 13.0 SP1.
- USB-Blaster JTAG programmer for hardware programming.

### Compile

From the repository root:

```bash
quartus_sh -t scripts/build.tcl
```

If `quartus_sh` is not in `PATH`, run the Quartus executable directly.

### Program FPGA

```bash
quartus_pgm -t scripts/program.tcl
```

The programming script expects:

```text
quartus/output_files/gameboy_core.sof
```

## Simulation

From `sim/modelsim`:

```bash
vsim -c -do run_blink_led.do
vsim -c -do run_vga_controller.do
vsim -c -do run_framebuffer.do
vsim -c -do run_pixel_pipeline.do
vsim -c -do run_framebuffer_top.do
vsim -c -do run_bus_controller.do
vsim -c -do run_cpu_all.do
vsim -c -do run_cpu_integration_top.do
vsim -c -do run_cpu_video_smoke_top.do
```

## Documentation

- [Architecture](docs/architecture.md)
- [Development roadmap](docs/development_roadmap.md)
- [Design decisions](docs/design_decisions.md)
- [Hardware bring-up](docs/hardware_bringup.md)
- [M3 CPU implementation](docs/m3_cpu.md)
- [M3/M4 checkpoint process](docs/m3_m4_checkpoint.md)
- [M3/M4 visual checkpoint report](docs/html/m3_m4_checkpoint.html)
- [Optimization process notes for TCC](docs/optimization_process_pt.md)
- [LinkedIn HRAM optimization post draft](docs/linkedin_hram_optimization_post_pt.md)
- [Resource utilization](docs/resource_utilization.md)
- [Pinout notes](docs/pinout_sources.md)

## License

MIT

## Author

Rafael Siqueira de Oliveira
