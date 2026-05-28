# Hardware Bring-Up Log

This file records hardware-facing validation performed on the OMDAZZ
RZ-EasyFPGA A2.2 board with the Altera Cyclone IV `EP4CE6E22C8N` FPGA.

## 2026-05-11

Toolchain:

- Quartus II 13.0 SP1 Web Edition
- USB-Blaster JTAG cable
- Target device detected by JTAG: `EP4CE6E22`
- JTAG ID code: `0x020F10DD`

## Tested Bitstreams

| Milestone | Top-level entity | Quartus result | JTAG programming result | Expected hardware observation |
| --- | --- | --- | --- | --- |
| M0 | `blink_led` | Full compilation successful | Configuration successful | LEDs blink from the 50 MHz board clock; each active-low key forces the matching LED on |
| M1 | `vga_test_top` | Full compilation successful | Configuration successful | VGA monitor shows vertical color bars; LED0 indicates PLL lock; LED1 toggles with VSync activity |
| M2 | `framebuffer_test_top` | Full compilation successful | Configuration successful | Confirmed on a VGA monitor through an active VGA-HDMI converter: centered 160x144 framebuffer test pattern scaled 3x with black borders; LED0 indicates PLL lock; LED1 toggles with VSync activity; LED2 indicates pattern completion; LED3 remains off |
| M3 integration | `cpu_integration_test_top` | Full compilation successful | Pending physical confirmation | LEDs show CPU checkpoint writes; the seven-segment display shows `1234` when all monitored CPU checks pass |

The JTAG and configuration path is confirmed for all current hardware tops.
M1 and M2 have been visually confirmed on the physical VGA monitor. Later
hardware-facing tops must still be confirmed through monitor, LED,
seven-segment, or SignalTap observations.

## Current M2 Resource Snapshot

Report source: `quartus/output_files/gameboy_core.fit.summary`

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 278 | 6,272 | 4% |
| Registers | 134 | 6,272 | 2% |
| Pins | 11 | 92 | 12% |
| Memory bits | 46,080 | 276,480 | 17% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

## Notes

- Key inputs are assigned to pins 88, 89, 90, and 91 for M0 and future joypad
  tests. Quartus reports these assignments as ignored when the selected
  top-level entity does not expose `key_n` ports.
- VGA currently uses scalar RGB pins verified for the early board tests:
  `vga_r` on pin 106, `vga_g` on pin 105, `vga_b` on pin 104, `vga_hsync` on
  pin 101, and `vga_vsync` on pin 103.
- The M2 framebuffer pattern was observed correctly through an active
  VGA-HDMI converter, so the current converter accepts the generated
  640x480@60 timing.
- After the M3 integration work, the canonical project top is
  `cpu_video_smoke_top` for CPU-to-framebuffer hardware validation.

## 2026-05-12 CPU Video Smoke Build

Top-level entity: `cpu_video_smoke_top`

Quartus result: full compilation successful, fully constrained in TimeQuest.

JTAG programming result: configuration successful, SOF checksum `0x00169AF4`.

Expected observation:

- VGA shows a mostly white Game Boy display area with CPU-written black pixels
  forming a small diagonal mark and a horizontal line.
- The four-digit seven-segment display shows `1234` after the CPU writes the
  expected framebuffer pixels and pass code.
- If the checker fails, the display shows `EEEE` and all LEDs are forced on.

Simulation coverage:

- `sim/modelsim/run_cpu_video_smoke_top.do` compiles the simulation PLL stub,
  CPU, framebuffer, VGA path, seven-segment driver, and the smoke top.
- `sim/modelsim/run_bus_controller.do` checks direct memory-map behavior for
  ROM, the initial WRAM page and echo mirror, HRAM, IF, IE, I/O stubs, debug
  overlay, and framebuffer writes.
- `tb_cpu_video_bus_controller` checks exactly 64 CPU framebuffer writes, each
  expected address, black pixel data, final LED checkpoint, and display value
  `1234`.
- `tb_cpu_video_smoke_top` checks the full top-level final LED checkpoint,
  seven-segment scan of `1234`, and active VGA black/white output.

## 2026-05-11 M3 CPU Integration Build

Top-level entity: `cpu_integration_test_top`

Report source: `quartus/output_files/gameboy_core.fit.summary`

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 1,021 | 6,272 | 16% |
| Registers | 216 | 6,272 | 3% |
| Pins | 18 | 92 | 20% |
| Memory bits | 0 | 276,480 | 0% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Expected observation:

- LEDs step through CPU-written checkpoint patterns and settle at hexadecimal
  `D` on the active-low LED bank.
- The four-digit seven-segment display shows `1234` after all monitored checks
  pass.
- If the checker fails, the display shows `EEEE` and all LEDs are forced on.
- Initial hardware observation showed `4321`, so the logical digit-enable pin
  mapping was reversed in `constraints/pin_assignments.qsf`.

## 2026-05-25 SDRAM ROM Execution Bring-Up

Top-level entity: `sdram_cpu_rom_top`

Purpose: validate the first end-to-end cartridge path:

1. load a 32 KiB no-MBC ROM into external SDRAM through Virtual JTAG;
2. release the CPU only after SDRAM initialization and loader completion;
3. fetch ROM bytes from SDRAM through `sdram_rom_reader`;
4. execute a minimal LED checkpoint program that writes to debug I/O `0xFF80`.

Initial symptom:

- Virtual JTAG reported successful transfer and final status `0x94`
  (`done`, `sdram_init`, and protocol signature set).
- The CPU reached at least one write to `0xFF80`.
- The expected final LED pattern did not appear consistently; the design looked
  as if execution stopped after the first visible checkpoint or accepted an
  unexpected value.

Debug method:

- Reduced the ROM to deterministic LED checkpoints.
- First tested direct `LD A,$0F` plus `LDH ($80),A`.
- Then removed dependency on the immediate `A` byte by generating `0x0F`
  through repeated `INC A`.
- Added compact LED diagnostics in `sdram_cpu_rom_top` to expose:
  - fetch checkpoint progress;
  - number of writes to `0xFF80`;
  - low nibble of CPU register `A`;
  - fatal error status.
- Added `tb_cpu_minimal_led_rom` to verify that the CPU alone executes the
  minimal checkpoint sequence correctly.

Root cause:

`sdram_rom_reader` asserted `rom_ready` from an internal ready register without
also checking that the current CPU address still matched the address that had
produced `rom_data`. During sequential instruction fetches, the CPU could move
to the next address while the reader still presented a ready pulse for the
previous byte. The bus has no address tag, so this stale ready condition could
be interpreted as valid data for the new fetch.

Fix:

```vhdl
rom_ready <= ready_reg when cpu_read = '1' and cpu_addr = addr_reg else '0';
```

Validation after the fix:

- `run_sdram_rom_reader.do` passes, including the case where `cpu_addr` changes
  while `cpu_read` remains asserted.
- `run_cpu_minimal_led_rom.do` passes.
- `scripts/build_sdram_cpu_rom.tcl` completes successfully and TimeQuest remains
  fully constrained.
- Hardware observation after loading the ROM through Virtual JTAG: all four LEDs
  are on in the summary view.

Final LED summary meaning:

- LED1: CPU fetched the final ROM checkpoint.
- LED2: CPU performed at least four writes to `0xFF80`.
- LED3: CPU register `A` reached `0x0F`.
- LED4: no fatal error was observed.

This bug is a useful portfolio/TCC case study because the failure was not in a
large subsystem such as the CPU or SDRAM initialization. It was a one-bit
validity contract at a module boundary. The successful diagnosis depended on
reducing the ROM, making hardware-visible checkpoints, and adding a regression
that captures the exact handshake behavior.

## 2026-05-28 SDRAM ROM to VGA Visual Bring-Up

Top-level entity: `sdram_video_rom_top`

ROM image: `roms/minimal_visual.gb`

Purpose: validate the first complete visual cartridge path:

1. load a 32 KiB no-MBC ROM into external SDRAM through Virtual JTAG;
2. release the CPU after SDRAM initialization and loader completion;
3. fetch ROM bytes from SDRAM through `sdram_rom_reader`;
4. let the CPU initialize VRAM, PPU registers, and the renderer start marker;
5. let the PPU render the ROM-authored tile pattern to the framebuffer and VGA.

Commands used:

```text
quartus_pgm -m jtag -o "p;quartus\output_files\gameboy_core.sof"
quartus_stp -t scripts\load_rom_virtual_jtag.tcl --progress-step 4096 roms\minimal_visual.gb
```

Loader result:

- initial status: `0x90` (`sdram_init`, protocol signature);
- final status: `0x94` (`done`, `sdram_init`, protocol signature);
- 32 KiB transferred successfully.

Hardware observation:

- all four board LEDs were on after execution;
- VGA showed the centered Game Boy viewport with the expected alternating
  white/checkerboard tile row produced by `minimal_visual.gb`.

Final LED summary meaning in `sdram_video_rom_top`:

- SDRAM initialization completed;
- Virtual JTAG ROM load completed;
- the CPU wrote the renderer start marker through `0xFF80`;
- the PPU completed at least one frame.

Checkpoint meaning:

This confirms the first practical visual cartridge flow:

```text
PC -> USB-Blaster -> Virtual JTAG -> SDRAM -> CPU -> VRAM -> PPU -> framebuffer -> VGA
```

The result is not yet a commercial game, but it proves that a project-owned
no-MBC ROM loaded from the host can execute from SDRAM and produce a real VGA
image through the hardware CPU/PPU path.
