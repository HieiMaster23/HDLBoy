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

## M4 Basic Bus Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_video_smoke_top`

Report date: 2026-05-13

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 3,161 | 6,272 | 50% |
| Registers | 1,304 | 6,272 | 21% |
| Pins | 27 | 92 | 29% |
| Memory bits | 46,080 | 276,480 | 17% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, `clk_50mhz` | 17.072 ns |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 25.089 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 206.862 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.452 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.501 ns |
| Hold, slow 1200 mV 85 C, `clk_50mhz` | 0.736 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- This slice adds HRAM at `0xFF80..0xFFFE`, IF at `0xFF0F`, and IE at
  `0xFFFF`.
- `0xFF80` and `0xFF81` remain debug overlays for the current smoke program.
- HRAM currently uses combinational CPU readback to match the existing CPU bus
  contract. This is correct for the current test but costs logic elements on
  the EP4CE6. A later bus controller with wait-state support should move HRAM
  toward a lower-resource RAM implementation.

## M4 WRAM and I/O Stub Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_video_smoke_top`

Report date: 2026-05-13

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 3,633 | 6,272 | 58% |
| Registers | 1,953 | 6,272 | 31% |
| Pins | 27 | 92 | 29% |
| Memory bits | 46,080 | 276,480 | 17% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, `clk_50mhz` | 17.073 ns |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 25.498 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 209.049 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.452 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.502 ns |
| Hold, slow 1200 mV 85 C, `clk_50mhz` | 0.737 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- This slice adds a deliberately small 64-byte WRAM page at
  `0xC000..0xC03F`, mirrored at `0xE000..0xE03F`, plus JOYP, serial, timer,
  LCD/PPU, DMA, and palette register stubs.
- A 256-byte combinational WRAM trial synthesized at 5,627 / 6,272 logic
  elements, or 90%, which is too high for the EP4CE6 resource budget. The
  committed design keeps the smaller 64-byte slice to preserve expansion room.
- Full WRAM/HRAM must not be implemented as large combinational register
  arrays on this device. The next bus/CPU architecture step should add
  registered RAM reads or wait states so Quartus can infer lower-resource RAM.

## M4 Registered WRAM and CPU Ready Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_video_smoke_top`

Report date: 2026-05-14

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 3,936 | 6,272 | 63% |
| Registers | 1,481 | 6,272 | 24% |
| Pins | 27 | 92 | 29% |
| Memory bits | 111,616 | 276,480 | 40% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, `clk_50mhz` | 17.073 ns |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 24.289 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 193.031 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.452 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.484 ns |
| Hold, slow 1200 mV 85 C, `clk_50mhz` | 0.737 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- The CPU now has a `mem_ready` input. Read states hold their current state until
  memory reports valid data, while existing combinational test memories tie the
  signal high.
- `bus_controller.vhd` now exposes `cpu_ready` and inserts a wait cycle for
  registered WRAM/HRAM reads.
- WRAM was expanded to the full DMG 8 KiB range `0xC000..0xDFFF`, with echo
  mapping through `0xE000..0xFDFF`.
- Quartus inferred WRAM as a single-port `altsyncram` with 8-bit width and
  8192 words. HRAM is still uninferred because it is only 127 bytes and shares
  temporary debug overlays at `0xFF80/0xFF81`.
- The previous unsafe direction was confirmed: a direct 8 KiB register-style
  WRAM did not fit synthesis. The registered-read version compiles at 63% logic
  element usage and 40% memory-bit usage.

## M3 LD (HL) Register Expansion

Canonical project: `gameboy_core`

Top-level entity: `cpu_video_smoke_top`

Report date: 2026-05-13

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 3,591 | 6,272 | 57% |
| Registers | 1,953 | 6,272 | 31% |
| Pins | 27 | 92 | 29% |
| Memory bits | 46,080 | 276,480 | 17% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, `clk_50mhz` | 17.072 ns |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 24.754 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 204.738 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.452 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.502 ns |
| Hold, slow 1200 mV 85 C, `clk_50mhz` | 0.736 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- This CPU slice generalizes the existing HL memory states to implement all
  `LD r,(HL)` and `LD (HL),r` register variants.
- The change reuses existing decode outputs and does not add a new CPU state,
  so the synthesis cost stays effectively flat.

## M3 ALU (HL) Expansion

Canonical project: `gameboy_core`

Top-level entity: `cpu_video_smoke_top`

Report date: 2026-05-13

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 3,616 | 6,272 | 58% |
| Registers | 1,953 | 6,272 | 31% |
| Pins | 27 | 92 | 29% |
| Memory bits | 46,080 | 276,480 | 17% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, `clk_50mhz` | 17.071 ns |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 25.098 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 205.076 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.452 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.500 ns |
| Hold, slow 1200 mV 85 C, `clk_50mhz` | 0.735 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- This CPU slice implements `ADD/SUB/AND/OR/XOR/CP A,(HL)` using the existing
  `S_MEM_READ_HL` state.
- No new CPU state was added. The resource increase is small and acceptable for
  the EP4CE6 budget.

## M3 INC/DEC (HL) Expansion

Canonical project: `gameboy_core`

Top-level entity: `cpu_video_smoke_top`

Report date: 2026-05-13

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 3,640 | 6,272 | 58% |
| Registers | 1,962 | 6,272 | 31% |
| Pins | 27 | 92 | 29% |
| Memory bits | 46,080 | 276,480 | 17% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, `clk_50mhz` | 17.073 ns |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 25.551 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 203.665 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.452 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.504 ns |
| Hold, slow 1200 mV 85 C, `clk_50mhz` | 0.737 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- This CPU slice implements `INC (HL)` and `DEC (HL)` as explicit
  read-modify-write instructions.
- The CPU now reuses `S_MEM_READ_HL` for the memory read and ALU flag update,
  then writes the captured ALU result back through `S_MEM_RMW_WRITE_HL`.
- The implementation keeps carry preservation in the ALU, matching LR35902
  `INC` and `DEC` flag behavior.
- The resource increase is 24 logic elements and 9 registers over the previous
  ALU `(HL)` slice, which is acceptable for this incremental M3 step.

## M3 LDH and Absolute A Memory Transfer Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_video_smoke_top`

Report date: 2026-05-13

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 3,566 | 6,272 | 57% |
| Registers | 1,964 | 6,272 | 31% |
| Pins | 27 | 92 | 29% |
| Memory bits | 46,080 | 276,480 | 17% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, `clk_50mhz` | 17.071 ns |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 24.389 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 202.512 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.452 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.503 ns |
| Hold, slow 1200 mV 85 C, `clk_50mhz` | 0.735 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- This slice implements `LDH (n),A`, `LDH A,(n)`, `LD (nn),A`, and
  `LD A,(nn)`.
- The CPU adds two shared states, `S_MEM_READ_ADDR` and `S_MEM_WRITE_ADDR`, so
  immediate I/O and absolute address transfers use the same datapath.
- The bus controller adds `serial_debug_valid` and `serial_debug_data`. A write
  to `0xFF02` with bit 7 set emits the current `0xFF01` byte for Blargg-style
  serial transcript capture in simulation.
- The fitter result is lower than the previous slice because Quartus changed
  logic packing during the full compile. This should be treated as equivalent
  resource class, not as a meaningful optimization win.

## M3 Interrupt Bring-Up Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_video_smoke_top`

Report date: 2026-05-14

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,087 | 6,272 | 65% |
| Registers | 1,500 | 6,272 | 24% |
| Pins | 27 | 92 | 29% |
| Memory bits | 111,616 | 276,480 | 40% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, `clk_50mhz` | 17.071 ns |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 25.589 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 196.004 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.452 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.501 ns |
| Hold, slow 1200 mV 85 C, `clk_50mhz` | 0.735 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- This slice adds initial real interrupt entry in the CPU: priority selection,
  PC push, vector jump, IME clear, `interrupt_ack`, and `RETI` IME restore.
- The bus controller now clears the serviced IF bit on `interrupt_ack` and has
  a minimal Timer IF stub for interrupt bring-up.
- The fitter result remains below the 80% warning threshold, but the design is
  already resource-sensitive at 65% logic element usage. Future timer, PPU, and
  SDRAM work should continue to prefer registered RAM templates, shared CPU
  states, and small incremental synthesis checks.

## M6 Initial DMG Timer Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_video_smoke_top`

Report date: 2026-05-15

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,157 | 6,272 | 66% |
| Registers | 1,500 | 6,272 | 24% |
| Pins | 27 | 92 | 29% |
| Memory bits | 111,616 | 276,480 | 40% |
| M9Ks | 14 | 30 | 47% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, `clk_50mhz` | 17.072 ns |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 25.705 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 196.475 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.451 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.484 ns |
| Hold, slow 1200 mV 85 C, `clk_50mhz` | 0.736 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- This slice replaces the duplicated timer stub with `rtl/io/timer.vhd`, adding
  shared DIV/TIMA/TMA/TAC behavior, TAC-selected divider edges, delayed TIMA
  reload, and a timer interrupt pulse.
- Compared with the previous interrupt bring-up slice, the fitter increased
  from 4,087 to 4,157 logic elements, a cost of 70 LEs while keeping registers,
  block memory usage, M9K count, and PLL usage unchanged.
- The design remains below the 80% warning threshold, but 66% logic usage keeps
  the EP4CE6 budget tight. Future work should continue to favor shared control
  states, inferred RAM, and incremental synthesis checkpoints.
