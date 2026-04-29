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
| M0 | Infrastructure and environment setup | Mostly complete |
| M1 | VGA controller 640x480 at 60 Hz | RTL and simulation complete |
| M2 | Framebuffer and pixel pipeline | RTL, simulation, and Quartus build complete; hardware test pending |
| M3 | CPU core - Sharp LR35902 | Not started |
| M4 | Memory map and bus controller | Not started |
| M5 | PPU | Not started |
| M6 | Timer, joypad, and I/O | Not started |
| M7 | SDRAM controller and ROM loading | Not started |
| M8 | Final integration and boot ROM | Not started |
| M9 | APU | Optional |
| M10 | PS/2 keyboard | Optional |

Current canonical Quartus top-level:

```text
framebuffer_test_top
```

The current build displays a generated Game Boy-sized framebuffer test pattern
through the VGA pipeline with 3x scaling.

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
```

## Documentation

- [Architecture](docs/architecture.md)
- [Design decisions](docs/design_decisions.md)
- [Resource utilization](docs/resource_utilization.md)
- [Pinout notes](docs/pinout_sources.md)

## License

MIT

## Author

Rafael Siqueira de Oliveira
