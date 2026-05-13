# Resource Utilization

This file records synthesis results by milestone. All numbers should come from
Quartus reports for the selected top-level entity and target device
`EP4CE6E22C8`.

## M0 / M1 Baseline

Existing generated reports were found for the legacy `vhdlboy` Quartus revision
using `vga_test_top` as the top-level entity.

Report date: 2026-03-27

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 62 | 6,272 | <1% |
| Registers | 39 | 6,272 | <1% |
| Pins | 17 | 92 | 18% |
| Memory bits | 0 | 276,480 | 0% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary for `vga_test_top` showed positive setup and hold slack on the
PLL-generated VGA clock.

## M2 Framebuffer Top

Canonical project: `gameboy_core`

Top-level entity: `framebuffer_test_top`

Report date: 2026-05-11

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 278 | 6,272 | 4% |
| Registers | 134 | 6,272 | 2% |
| Pins | 11 | 92 | 12% |
| Memory bits | 46,080 | 276,480 | 17% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C | 28.384 ns |
| Hold, slow 1200 mV 85 C | 0.410 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |
| Minimum pulse width, PLL VGA clock | 19.582 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- The framebuffer is inferred as a 23,040-word x 2-bit M9K RAM.
- The generated framebuffer image was visually confirmed in hardware through
  an active VGA-HDMI converter.
- The current board top maps the internal 3-bit RGB channels to scalar VGA
  pins through simple spatial dithering so both framebuffer bits remain active.
- Remaining warnings are expected for this milestone: `led[3]` is intentionally
  tied off, the PLL CPU output is generated but unused in the M2 top, and
  Quartus reports general 3.3-V LVTTL advisory notes for the clock/reset pins.

## M3 CPU Integration Top

Canonical project: `gameboy_core`

Top-level entity: `cpu_integration_test_top`

Report date: 2026-05-11

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 1,021 | 6,272 | 16% |
| Registers | 216 | 6,272 | 3% |
| Pins | 18 | 92 | 20% |
| Memory bits | 0 | 276,480 | 0% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C | 17.071 ns |
| Hold, slow 1200 mV 85 C | 0.452 ns |
| Minimum pulse width, `clk_50mhz` | 9.742 ns |
| Minimum pulse width, PLL CPU clock | 118.925 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- The integration harness intentionally uses sparse writable memory registers
  instead of a full RAM, keeping the hardware test small enough for the EP4CE6.
- The first attempt with 256-byte WRAM and HRAM arrays used 95% of the FPGA; it
  was reduced before hardware programming.

## M3 CPU Video Smoke Top

Canonical project: `gameboy_core`

Top-level entity: `cpu_video_smoke_top`

Report date: 2026-05-13

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 1,367 | 6,272 | 22% |
| Registers | 275 | 6,272 | 4% |
| Pins | 27 | 92 | 29% |
| Memory bits | 46,080 | 276,480 | 17% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, `clk_50mhz` | 17.072 ns |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 24.899 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 214.306 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.452 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.502 ns |
| Hold, slow 1200 mV 85 C, `clk_50mhz` | 0.736 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- This top combines the M3 CPU subset, the initial `bus_controller`, the M2
  framebuffer, VGA timing, pixel upscaling, LEDs, and the four-digit
  seven-segment display.
- The bus controller maps the smoke ROM at `0x0000`, an experimental
  framebuffer/VRAM write window at `0x8000`, and debug I/O at `0xFF80` and
  `0xFF81`.
- The CPU writes 64 black pixels into the framebuffer-mapped address window
  and then writes a pass code to an I/O register.
- JTAG programming completed successfully with SOF checksum `0x00169AF4`.
