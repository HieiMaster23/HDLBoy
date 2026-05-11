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
| M2 | `framebuffer_test_top` | Full compilation successful | Configuration successful | VGA monitor shows the centered 160x144 framebuffer test pattern scaled 3x with black borders; LED0 indicates PLL lock; LED1 toggles with VSync activity; LED2 indicates pattern completion; LED3 remains off |

The JTAG and configuration path is confirmed for all current hardware tops.
Visual confirmation must be performed by observing the physical VGA monitor and
LEDs, because those signals are not visible from the build environment.

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
- The canonical project top is restored to `framebuffer_test_top` after the
  sequential hardware test pass.
