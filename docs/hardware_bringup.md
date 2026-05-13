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
