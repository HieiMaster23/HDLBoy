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
| M3 | CPU core - Sharp LR35902 | Broad multi-cycle subset implemented; all individual Blargg `cpu_instrs`, `instr_timing`, `mem_timing`, `mem_timing-2`, and `interrupt_time` ROMs pass |
| M4 | Memory map and bus controller | Initial bus, full WRAM, HRAM, IE/IF, and memory-ready path implemented |
| M5 | PPU | Not started |
| M6 | Timer, joypad, and I/O | Initial DMG timer implemented; joypad and remaining I/O still pending |
| M7 | SDRAM controller and ROM loading | Not started |
| M8 | Final integration and boot ROM | Not started |
| M9 | APU | Optional |
| M10 | PS/2 keyboard | Optional |

Current canonical Quartus top-level:

```text
cpu_video_smoke_top
```

The current build runs a CPU-to-framebuffer smoke test program from a small
internal ROM. The CPU writes directly into a framebuffer-mapped address window,
VGA displays the result, and the four-digit seven-segment display shows `1234`
when the monitored integration checks pass.

The current development focus is the transition from functionally correct CPU
behavior toward timing-faithful CPU behavior. The individual Blargg
`cpu_instrs`, `instr_timing`, `mem_timing`, `mem_timing-2`, and
`interrupt_time` ROMs now pass through the ROM runner, so the next CPU
validation layer is HALT-edge-case work before beginning the real PPU.

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
- [Resource utilization](docs/resource_utilization.md)
- [Pinout notes](docs/pinout_sources.md)

## License

MIT

## Author

Rafael Siqueira de Oliveira
