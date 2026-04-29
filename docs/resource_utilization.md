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

Report date: 2026-04-29

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 271 | 6,272 | 4% |
| Registers | 127 | 6,272 | 2% |
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
- The current board top maps the internal 3-bit RGB channels to scalar VGA
  pins through simple spatial dithering so both framebuffer bits remain active.
- Remaining warnings are expected for this milestone: `led[3]` is intentionally
  tied off, the PLL CPU output is generated but unused in the M2 top, and
  Quartus reports general 3.3-V LVTTL advisory notes for the clock/reset pins.
