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

## M3 Instruction Timing Bring-Up Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_video_smoke_top`

Report date: 2026-05-15

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,251 | 6,272 | 68% |
| Registers | 1,500 | 6,272 | 24% |
| Pins | 27 | 92 | 29% |
| Memory bits | 111,616 | 276,480 | 40% |
| M9Ks | 14 | 30 | 47% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, `clk_50mhz` | 17.071 ns |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 24.480 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 177.247 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.451 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.502 ns |
| Hold, slow 1200 mV 85 C, `clk_50mhz` | 0.735 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- This slice adds fetch-stage fast paths for the first instruction families
  proven to be one M-cycle too long during `instr_timing` bring-up.
- Compared with the previous timer slice, the fitter increased from 4,157 to
  4,251 logic elements, a cost of 94 LEs while register count, memory usage,
  M9K count, and PLL usage stayed flat.
- `instr_timing.gb` now gets past its initial timer self-check and reaches the
  opcode timing phase, but the ROM does not pass yet.
- At 68% logic utilization, the design still has margin on the EP4CE6, but
  timing fidelity must keep being added selectively rather than by duplicating
  large control structures.

## M3 Instruction Timing Expansion Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_video_smoke_top`

Report date: 2026-05-15

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,511 | 6,272 | 72% |
| Registers | 1,501 | 6,272 | 24% |
| Pins | 27 | 92 | 29% |
| Memory bits | 111,616 | 276,480 | 40% |
| M9Ks | 14 | 30 | 47% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, `clk_50mhz` | 17.071 ns |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 24.693 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 169.147 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.452 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.650 ns |
| Hold, slow 1200 mV 85 C, `clk_50mhz` | 0.735 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- This slice extends timing coverage to indirect pair loads/stores,
  accumulator rotates, `DAA/CPL/SCF/CCF`, `LD (nn),SP`, and taken/not-taken
  conditional relative jumps.
- `JR cc,e` now has distinct timing behavior: 2 M-cycles when not taken and
  3 M-cycles when taken.
- Compared with the prior timing bring-up slice, the fitter increased from
  4,251 to 4,511 logic elements, a cost of 260 LEs for this expanded control
  work.
- The design still fits with timing margin, but 72% LE usage is a clear signal
  that the current fetch fast-path style should be refactored before many more
  timing families are added. Continuing with duplicated execution logic would
  spend EP4CE6 headroom too quickly.

## M3 Instruction Timing Control Refactor Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_video_smoke_top`

Report date: 2026-05-15

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,268 | 6,272 | 68% |
| Registers | 1,501 | 6,272 | 24% |
| Pins | 27 | 92 | 29% |
| Memory bits | 111,616 | 276,480 | 40% |
| M9Ks | 14 | 30 | 47% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, `clk_50mhz` | 17.072 ns |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 26.480 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 174.655 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.452 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.502 ns |
| Hold, slow 1200 mV 85 C, `clk_50mhz` | 0.736 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- This slice refactors the fetch control after the initial timing expansion.
- Shared opcode helper predicates now classify register-addressed memory
  transfers for both `S_FETCH` and `S_DECODE`.
- Duplicate register-only `LD r,r`, `INC/DEC r`, `ALU r`, and one-cycle
  accumulator/flag-control execution bodies were removed from the decode path.
- Compared with the previous timing expansion slice, the fitter dropped from
  4,511 to 4,268 logic elements, recovering 243 LEs while preserving the
  expanded timing coverage and the Blargg regressions used for this slice.
- A generic decoder-metadata routing experiment for `LD_MEM` was rejected after
  it broke the WRAM copy flow exercised by `06-ld r,r.gb`; the final
  implementation keeps the small explicit opcode distinction because it is both
  safer and cheaper on the EP4CE6.

## M3 Blargg Timing Checkpoint

Canonical project: `gameboy_core`

Top-level entity: `cpu_video_smoke_top`

Report date: 2026-05-16

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,283 | 6,272 | 68% |
| Registers | 1,502 | 6,272 | 24% |
| Pins | 27 | 92 | 29% |
| Memory bits | 111,616 | 276,480 | 40% |
| M9Ks | 14 | 30 | 47% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, `clk_50mhz` | 17.072 ns |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 24.697 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 174.035 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.452 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.501 ns |
| Hold, slow 1200 mV 85 C, `clk_50mhz` | 0.736 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- This slice promotes the CPU-visible TIMA read value used by the current
  M-cycle bus model, allowing Blargg `instr_timing.gb` to reach `Passed`.
- Blargg `mem_timing` individual ROMs `01-read_timing.gb`,
  `02-write_timing.gb`, and `03-modify_timing.gb` reached `Passed`.
- The aggregate Blargg `mem_timing.gb` ROM also reached `Passed`.
- Blargg `mem_timing-2` individual ROMs and aggregate ROM reached `Passed` in
  simulation after extending the ROM runner to observe the documented memory
  status protocol at `0xA000`.
- Compared with the prior control-refactor checkpoint, the fitter increased
  from 4,268 to 4,283 logic elements, a cost of 15 LEs. The design remains at
  68% logic utilization, with memory and PLL use unchanged.
- The `mem_timing-2` runner support is testbench-only, so it does not change
  FPGA resource utilization.

## First VRAM Foundation Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_video_smoke_top`

Report date: 2026-05-16

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,290 | 6,272 | 68% |
| Registers | 1,502 | 6,272 | 24% |
| Pins | 27 | 92 | 29% |
| Memory bits | 177,152 | 276,480 | 64% |
| M9Ks | 22 | 30 | 73% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, `clk_50mhz` | 17.073 ns |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 23.376 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 178.193 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.452 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.502 ns |
| Hold, slow 1200 mV 85 C, `clk_50mhz` | 0.737 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- This slice reserves real 8 KiB VRAM at `0x8000..0x9FFF` and keeps the older
  framebuffer smoke window separate at `0xA000..0xBFFF`.
- `rtl/memory/vram.vhd` adds the first dedicated video memory block plus a
  future PPU read port, while `tb_vram` and the bus-controller regression prove
  CPU-visible VRAM read/write behavior.
- Compared with the prior timing checkpoint, logic rises only from 4,283 to
  4,290 LEs, but memory grows from 111,616 to 177,152 bits and M9K use rises from
  14 to 22 blocks. The new PPU phase is therefore memory-sensitive even before
  tile fetch logic is added.
- Quartus currently reduces the top-level unused PPU read port away in the
  smoke build, so the next PPU slice should consume that port with a real tile
  producer before treating the dual-port behavior as fully exercised in the
  synthesized top.

## First Background PPU Demo Top

Canonical project: `gameboy_core`

Top-level entity: `ppu_background_demo_top`

Report date: 2026-05-16

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 405 | 6,272 | 6% |
| Registers | 144 | 6,272 | 2% |
| Pins | 11 | 92 | 12% |
| Memory bits | 111,616 | 276,480 | 40% |
| M9Ks | 14 | 30 | 47% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 25.854 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 230.609 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.442 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.510 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- This is an intentionally partial visual top, not the complete system top:
  CPU and full WRAM are absent, so its logic-element count must not be compared
  directly with the CPU smoke checkpoint.
- The slice adds a real VRAM-to-PPU-to-framebuffer path:
  `ppu_demo_loader` populates VRAM, `ppu_background_renderer` reads tile data
  plus the background tile map, and VGA displays the generated framebuffer.
- Quartus now infers VRAM as an actual dual-port M9K-backed memory in the
  synthesized top: 8 M9Ks for VRAM and 6 M9Ks for the framebuffer.
- This is the first useful resource measurement of the PPU phase. The visual
  slice is cheap in logic so far, but the VRAM/framebuffer pair already consumes
  14 of the 30 available M9Ks.

## First CPU-to-PPU Background Integration Top

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-16

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,235 | 6,272 | 68% |
| Registers | 1,515 | 6,272 | 24% |
| Pins | 11 | 92 | 12% |
| Memory bits | 177,152 | 276,480 | 64% |
| M9Ks | 22 | 30 | 73% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 26.077 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 176.423 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.413 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.500 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- This is the first top where the CPU writes the VRAM contents that the PPU
  later renders. The program writes tile 0, tile 1, the background map, then a
  completion marker at `0xFF80` before the renderer starts.
- The integrated visual path is now:
  `CPU -> bus_controller -> VRAM -> ppu_background_renderer -> framebuffer -> VGA`.
- The expected centered tile pattern was visually confirmed on the real OMDAZZ
  hardware after programming this top.
- Compared with the earlier VRAM foundation top, the logic-element count remains
  in the same resource class while the real PPU-side VRAM port is now exercised
  by the full CPU-bearing system.
- Quartus reports 22 M9Ks in use: 8 for VRAM, 8 for WRAM, and 6 for the
  framebuffer. Memory, not logic, is already the tighter medium-term resource
  for the visual path on EP4CE6.
- Rebuilding the same top on 2026-05-17 after extracting the smoke and
  CPU/PPU demo programs into standalone ROM modules kept utilization unchanged:
  `4,235` logic elements, `177,152` block-memory bits, and `22` M9Ks.
- Rebuilding the same top on 2026-05-18 after adding `SCX`/`SCY` background
  offsets used `4,251` logic elements, `1,519` registers, `177,152`
  block-memory bits, and `22` M9Ks. The first visible LCD-register behavior
  therefore costs only 16 additional logic elements in the current design.

## Initial Scanline-Oriented Background Renderer

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-19

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,271 | 6,272 | 68% |
| Registers | 1,522 | 6,272 | 23% |
| Pins | 11 | 92 | 12% |
| Memory bits | 177,152 | 276,480 | 64% |
| M9Ks | 22 | 30 | 73% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 25.517 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 176.006 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.501 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.445 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- The background renderer now has explicit scanline states and exposes
  `current_line`, `line_active`, and `line_done` signals. This is still not a
  full DMG PPU timing engine, but it creates a clean boundary for future LY,
  STAT, mode, and VBlank work.
- `tb_ppu_background_renderer` now checks that each render completes exactly
  144 visible scanlines while preserving the existing tile and `SCX`/`SCY`
  pixel checks.
- Compared with the prior `SCX`/`SCY` build, this costs 20 logic elements and 3
  registers. Memory usage, M9K usage, multiplier usage, and PLL usage remain
  unchanged, which is acceptable for this structural PPU step on EP4CE6.

## Minimal LY/STAT PPU Register Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-19

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,283 | 6,272 | 68% |
| Registers | 1,522 | 6,272 | 23% |
| Pins | 11 | 92 | 12% |
| Memory bits | 177,152 | 276,480 | 64% |
| M9Ks | 22 | 30 | 73% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 23.633 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 176.247 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.501 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.426 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- The bus now reads `LY` from the PPU scanline signal and computes minimal
  `STAT` readback from writable bits 6..3, the `LY=LYC` coincidence bit, and a
  provisional mode field.
- The provisional mode field reports Mode 3 while the current background line is
  active and Mode 0 otherwise. This is only a bring-up model; it is not yet the
  final dot-accurate DMG PPU mode scheduler.
- Compared with the scanline-structure build, this costs 12 logic elements and
  no additional registers or memory blocks.

## Initial PPU Mode Scheduler Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-19

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,300 | 6,272 | 69% |
| Registers | 1,523 | 6,272 | 24% |
| Pins | 11 | 92 | 12% |
| Memory bits | 177,152 | 276,480 | 64% |
| M9Ks | 22 | 30 | 73% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 24.858 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 173.602 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.499 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.348 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- The background renderer now exposes an explicit 2-bit PPU mode output.
  The bus controller routes this directly into the `STAT` mode field.
- The current scheduler reports deterministic line-level modes: Mode 2 at
  visible-line start, Mode 3 while the current background line is rendered,
  Mode 0 at visible-line end, and Mode 1 across the initial VBlank lines
  `144..153`.
- This is still not dot-accurate DMG PPU timing. It is a controlled structural
  step that replaces the previous active-line placeholder and prepares the
  design for VBlank and STAT interrupt generation.
- Compared with the minimal LY/STAT slice, this costs 17 logic elements and
  1 register, with no additional block-memory or M9K usage.

## Initial VBlank and STAT Interrupt Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-20

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,324 | 6,272 | 69% |
| Registers | 1,525 | 6,272 | 24% |
| Pins | 11 | 92 | 12% |
| Memory bits | 177,152 | 276,480 | 64% |
| M9Ks | 22 | 30 | 73% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 24.874 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 176.049 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.502 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.438 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- The bus controller now raises IF bit 0 on the initial VBlank entry condition
  and IF bit 1 on enabled STAT conditions.
- STAT interrupt sources currently include Mode 0, Mode 1, Mode 2, and
  `LY=LYC` coincidence through writable STAT bits 3, 4, 5, and 6.
- Requests are edge-detected at the combined condition level so acknowledging an
  interrupt while the condition remains high does not immediately reassert the
  same IF bit.
- This remains a line-level PPU interrupt foundation. Dot-accurate STAT timing,
  LCD enable behavior, OAM, sprites, and DMA are still future work.
- Compared with the initial mode scheduler slice, this costs 24 logic elements
  and 2 registers, with no additional block-memory or M9K usage.

## PPU Dot Scheduler Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-20

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,342 | 6,272 | 69% |
| Registers | 1,535 | 6,272 | 24% |
| Pins | 11 | 92 | 12% |
| Memory bits | 177,152 | 276,480 | 64% |
| M9Ks | 22 | 30 | 73% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 25.133 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 174.629 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.502 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.451 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- The background renderer now carries a logical dot counter for each scanline.
- Visible lines use 456 dots: Mode 2 at dots `0..79`, Mode 3 at `80..251`,
  and Mode 0 at `252..455`.
- VBlank lines `144..153` report Mode 1 and also advance through the same
  `0..455` dot range.
- The renderer exposes `current_dot` for simulation and future debug probes.
- This is still a scheduler foundation. The background fetch path remains the
  existing simple renderer and does not yet model the real FIFO/fetcher,
  variable Mode 3 duration, sprites, window, DMA, or LCD enable behavior.
- Compared with the initial VBlank/STAT interrupt slice, this costs 18 logic
  elements and 10 registers, with no additional block-memory or M9K usage.

## Initial LCDC Enable Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-20

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,362 | 6,272 | 70% |
| Registers | 1,535 | 6,272 | 24% |
| Pins | 11 | 92 | 12% |
| Memory bits | 177,152 | 276,480 | 64% |
| M9Ks | 22 | 30 | 73% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 25.994 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 175.574 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.500 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.452 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- `bus_controller` now exposes `ppu_lcd_enable` from `LCDC(7)`.
- When LCDC bit 7 is clear, CPU-visible `LY` is forced to zero and `STAT`
  evaluates using Mode 0 plus line zero.
- VBlank and STAT interrupt requests from the PPU scheduler are masked while
  LCDC bit 7 is clear.
- `ppu_background_renderer` now receives `lcd_enable` and holds its internal
  state, line counter, dot counter, framebuffer write enable, busy, and done
  inactive while the LCD is disabled.
- Compared with the dot scheduler slice, this costs 20 logic elements and no
  additional registers, block-memory bits, or M9K blocks.

## Initial VRAM Mode 3 Access Blocking Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-20

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,361 | 6,272 | 70% |
| Registers | 1,535 | 6,272 | 24% |
| Pins | 11 | 92 | 12% |
| Memory bits | 177,152 | 276,480 | 64% |
| M9Ks | 22 | 30 | 73% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 25.007 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 177.365 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.452 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.501 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- `bus_controller` now blocks CPU access to VRAM when LCDC bit 7 is set, the
  effective PPU mode is Mode 3, and the CPU address is in `0x8000..0x9FFF`.
- CPU reads from blocked VRAM return `0xFF`; CPU writes are ignored.
- When LCDC bit 7 is clear, VRAM remains CPU-accessible even if the raw PPU
  mode input is Mode 3.
- This preserves the current CPU-authored background demo because the CPU fills
  VRAM before rendering starts.
- Compared with the LCDC enable slice, the reported logic-element count changed
  from 4,362 to 4,361. Treat this as fitter variation from a near-zero-cost
  control change, not as a meaningful optimization.

## Initial OAM Storage and Access Blocking Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-20

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,344 | 6,272 | 69% |
| Registers | 1,535 | 6,272 | 24% |
| Pins | 11 | 92 | 12% |
| Memory bits | 179,200 | 276,480 | 65% |
| M9Ks | 23 | 30 | 77% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 25.532 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 174.644 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.452 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.499 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- `bus_controller` now exposes the CPU OAM window at `0xFE00..0xFE9F`.
- CPU OAM reads return `0xFF` during Mode 2 or Mode 3 while LCDC bit 7 is set;
  CPU OAM writes are ignored in the same modes.
- OAM remains CPU-accessible while LCDC bit 7 is clear.
- The unusable `0xFEA0..0xFEFF` range remains unmapped and reads as `0xFF`.
- The physical RAM is intentionally inferred as 256 x 8 bits in one M9K block
  while only the DMG-visible 160-byte OAM window is decoded. The first 160-byte
  template synthesized as distributed logic and pushed the design to 96% logic
  utilization, so the M9K-backed template is the correct resource trade-off for
  this board.
- Compared with the VRAM Mode 3 blocking slice, this adds one M9K block and
  2,048 memory bits while keeping logic use in the same class.

## Continuous PPU Frame Loop Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-20

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,357 | 6,272 | 69% |
| Registers | 1,536 | 6,272 | 24% |
| Pins | 11 | 92 | 12% |
| Memory bits | 179,200 | 276,480 | 65% |
| M9Ks | 23 | 30 | 77% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 23.048 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 178.965 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.440 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.500 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- `ppu_background_renderer` now loops continuously while LCDC bit 7 is enabled.
- `done` is now a one-cycle frame-complete pulse instead of a permanent terminal
  state.
- The visual tops latch the pulse into `ppu_frame_seen` for stable LED debug
  indication without making the PPU core one-shot again.
- `start` remains a kick signal for the first frame so demo tops can finish
  authoring VRAM before the renderer starts.
- Compared with the initial OAM slice, this costs 13 logic elements and one
  register, with no additional memory blocks.

## BGP Palette Lookup Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-20

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,342 | 6,272 | 69% |
| Registers | 1,536 | 6,272 | 24% |
| Pins | 11 | 92 | 12% |
| Memory bits | 179,200 | 276,480 | 65% |
| M9Ks | 23 | 30 | 77% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 25.271 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 177.321 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.373 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.510 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- `bus_controller` now exposes the `BGP` register to the PPU path as `ppu_bgp`.
- `ppu_background_renderer` converts the 2-bit background tile color id into
  the final 2-bit framebuffer shade using the DMG BGP bit pairs.
- The default `BGP = 0xFC` preserves the existing visual baseline while allowing
  CPU-authored palettes to affect future rendered frames.
- No additional memory blocks were introduced. The fitted logic count decreased
  slightly versus the continuous-frame slice due to Quartus optimization changes.

## LCDC Background Control Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-20

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,382 | 6,272 | 70% |
| Registers | 1,536 | 6,272 | 24% |
| Pins | 11 | 92 | 12% |
| Memory bits | 179,200 | 276,480 | 65% |
| M9Ks | 23 | 30 | 77% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 23.962 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 176.222 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.446 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.501 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- `bus_controller` now exposes the full `LCDC` register to the PPU path as
  `ppu_lcdc`.
- `ppu_background_renderer` uses `LCDC(3)` to select the background tile map at
  VRAM local `0x1800` or `0x1C00`.
- `LCDC(4)` now selects unsigned tile data at VRAM local `0x0000` or signed tile
  data centered at VRAM local `0x1000`.
- `LCDC(0)` initially controls background enable by forcing background color id
  0 through `BGP` when clear.
- The slice costs 40 logic elements versus the BGP checkpoint and does not add
  registers or memory blocks.

## Initial PPU OAM Scan Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-20

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,438 | 6,272 | 71% |
| Registers | 1,552 | 6,272 | 25% |
| Pins | 11 | 92 | 12% |
| Memory bits | 179,200 | 276,480 | 65% |
| M9Ks | 23 | 30 | 77% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 25.444 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 174.984 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.451 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.485 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- `ppu_oam_scan` adds the first PPU-side OAM scan engine.
- The scanner runs from the Mode 2 dot-zero pulse and scans 40 sprite entries in
  80 cycles, matching the current Mode 2 budget.
- Candidate detection uses the sprite Y coordinate, the current scanline, and
  `LCDC(2)` for 8x8 versus 8x16 sprite height.
- The scanner records up to 10 candidate sprite indices for the current line,
  matching the DMG per-scanline sprite limit.
- Candidate collection is gated by `LCDC(1)`, so sprite-disabled operation does
  not evaluate unused OAM contents.
- `bus_controller` now exposes a PPU OAM read port while preserving CPU OAM
  access blocking during Mode 2/3.
- Compared with the LCDC background-control slice, this costs 56 logic elements
  and 16 registers, with no additional memory blocks.

## First Sprite Pixel Fetch/Composition Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-20

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,551 | 6,272 | 73% |
| Registers | 1,614 | 6,272 | 26% |
| Pins | 11 | 92 | 12% |
| Memory bits | 179,200 | 276,480 | 65% |
| M9Ks | 23 | 30 | 77% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 24.706 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 170.635 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.388 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.517 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- `ppu_background_renderer` now consumes the first OAM scan candidate and fetches
  that sprite's OAM Y, X, tile index, and attributes before writing the line.
- The renderer fetches the selected sprite tile row through the existing PPU
  VRAM port and overlays nonzero OBJ pixels on top of the background.
- `OBP0` is exposed from the bus to the renderer and is used for this first OBJ
  palette lookup.
- `LCDC(1)` disables sprite composition, preserving the previous background-only
  visual output when sprites are disabled.
- Attribute bits 5 and 6 are used for initial horizontal and vertical flip.
  OBP1 selection, priority, multi-sprite composition, ordering, window
  interaction, and exact FIFO timing remain future work.
- Compared with the initial OAM scan slice, this costs 113 logic elements and
  62 registers, with no additional block-memory or M9K usage.

## Sprite Palette/Priority/Two-Candidate Composition Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-20

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,649 | 6,272 | 74% |
| Registers | 1,670 | 6,272 | 27% |
| Pins | 11 | 92 | 12% |
| Memory bits | 179,200 | 276,480 | 65% |
| M9Ks | 23 | 30 | 77% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 22.991 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 177.401 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.425 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.503 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- `bus_controller` now exposes `OBP1` to the PPU path.
- `ppu_background_renderer` stores two small sprite composition slots for the
  current line and fetches up to the first two OAM scan candidates.
- Sprite composition now selects `OBP0` or `OBP1` from attribute bit 4.
- Attribute bit 7 implements the initial BG/OBJ priority rule: OBJ pixels marked
  behind BG are hidden by nonzero background color ids and remain visible over
  background color id 0.
- Within this first two-candidate slice, candidates are composed in the order
  supplied by OAM scan, and the first visible nontransparent OBJ pixel wins.
- This is still not the final DMG OBJ pipeline: full 10-candidate composition,
  DMG sprite ordering details, window interaction, and exact FIFO timing remain
  future work.
- Compared with the first sprite pixel fetch/composition slice, this costs 98
  logic elements and 56 registers, with no additional block-memory or M9K usage.

## Full 10-Candidate Sprite Composition Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-20

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 5,286 | 6,272 | 84% |
| Registers | 1,935 | 6,272 | 31% |
| Pins | 11 | 92 | 12% |
| Memory bits | 179,200 | 276,480 | 65% |
| M9Ks | 23 | 30 | 77% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 26.370 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 178.275 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.452 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.502 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- `ppu_background_renderer` now stores up to the 10 per-line sprite candidates
  produced by `ppu_oam_scan`, matching the DMG scanline candidate limit.
- The renderer still composes candidates in OAM-scan order and uses the first
  visible nontransparent OBJ pixel that is not hidden by BG priority.
- The slot storage was kept compact by retaining per-slot X, attributes, and
  fetched tile-row bytes only. Sprite Y and tile index are now single current
  fetch registers because they are not needed after each candidate row is read.
- The directed renderer test now covers a line with 10 candidates where the
  tenth candidate is the first visible OBJ pixel.
- Compared with the two-candidate composition slice, this costs 637 logic
  elements and 265 registers, with no additional block-memory or M9K usage.
- At 84% logic utilization, this checkpoint is above the project's 80% resource
  caution threshold. Before adding Window or a more faithful FIFO, the next PPU
  step should look for a lower-cost sprite composition structure.

## Serialized 10-Candidate Sprite Composition Optimization

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-20

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 5,013 | 6,272 | 80% |
| Registers | 1,945 | 6,272 | 31% |
| Pins | 11 | 92 | 12% |
| Memory bits | 179,200 | 276,480 | 65% |
| M9Ks | 23 | 30 | 77% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 25.084 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 178.146 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.452 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.518 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- Sprite composition now evaluates one stored candidate per internal composition
  cycle instead of building a 10-way combinational selector in the framebuffer
  write path.
- The background color id and final framebuffer shade are registered before the
  sprite walk, so OBP0/OBP1 palette selection and BG/OBJ priority behavior are
  preserved.
- Compared with the direct full 10-candidate composition slice, this saves 273
  logic elements while adding 10 registers and no memory blocks.
- The `ppu_background_renderer` hierarchy dropped from 1,004 to 740 logic cells,
  a local reduction of 264 logic cells.
- The trade-off is internal latency: a pixel with enabled sprites may spend up
  to 10 additional composition cycles before the framebuffer write. The current
  scheduler is still an abstract renderer, not a dot-accurate FIFO pipeline.
- At exactly 80% logic utilization, the design is back at the resource caution
  threshold but not comfortably below it. The next optimization target should be
  the VGA pixel pipeline multipliers and then bus/debug logic that is not needed
  in the final playable top.

## VGA Pixel Pipeline Raster Scaler Optimization

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-20

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,995 | 6,272 | 80% |
| Registers | 1,965 | 6,272 | 31% |
| Pins | 11 | 92 | 12% |
| Memory bits | 179,200 | 276,480 | 65% |
| M9Ks | 23 | 30 | 77% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 29.175 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 175.177 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.377 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.454 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- `vga_pixel_pipeline` no longer computes `(pixel - offset) / 3` with
  reciprocal multiplication.
- The scaler now assumes raster-ordered coordinates from `vga_controller` and
  tracks the fixed 3x scale with modulo-3 horizontal/vertical phases.
- The framebuffer address is generated from a registered line base plus the
  current Game Boy X coordinate, avoiding the two inferred `lpm_mult` structures
  previously visible in the hierarchy report.
- The `vga_pixel_pipeline` hierarchy dropped from 141 to 117 logic cells while
  adding 20 registers for the scale counters and line base.
- Compared with the serialized sprite composition checkpoint, the full top
  drops from 5,013 to 4,995 logic elements. Quartus still rounds this to 80%,
  so the project remains resource-sensitive.
- The next optimization target should be non-final debug/bus logic rather than
  the APU. Audio remains deferred until the first non-audio playable system is
  functional.

## Configurable Bus Debug Feature Split

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-20

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 4,995 | 6,272 | 80% |
| Registers | 1,965 | 6,272 | 31% |
| Pins | 11 | 92 | 12% |
| Memory bits | 179,200 | 276,480 | 65% |
| M9Ks | 23 | 30 | 77% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 29.175 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 175.177 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.377 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.454 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- `bus_controller` now has generics for demo-only features:
  `G_ENABLE_FB_WINDOW`, `G_ENABLE_SMOKE_CHECKER`, and
  `G_ENABLE_SERIAL_DEBUG`.
- The standalone bus and CPU-to-framebuffer smoke tests keep the default
  generic values enabled, preserving the existing smoke contracts.
- `ppu_background_demo_top` and `cpu_ppu_background_demo_top` explicitly
  disable these demo-only features because they only need the debug completion
  marker at `0xFF80`, not the experimental CPU-to-framebuffer window or
  pass-code checker.
- Quartus had already removed the unused open-output debug path from the
  current CPU/PPU top, so this split did not reduce the final fitted top below
  the previous 4,995 logic element checkpoint. The value is still useful because
  the hardware boundary is now explicit and future tops can opt into or out of
  smoke-only logic intentionally.
- A separate experiment replaced wide memory-map range compares with bit-level
  address decodes. It passed simulation, but the fitted result worsened to
  5,025 logic elements, so that experiment was rejected and not kept.
- The next meaningful optimization should target actual retained logic, not
  already-pruned open-output debug paths. HRAM remains a likely candidate, but
  it needs a read-path restructuring; a simple RAM style attribute was already
  shown not to infer an M9K on this design.

## HRAM M9K Inference Optimization

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-21

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 3,674 | 6,272 | 59% |
| Registers | 941 | 6,272 | 15% |
| Pins | 11 | 92 | 12% |
| Memory bits | 180,224 | 276,480 | 65% |
| M9Ks | 24 | 30 | 80% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 29.546 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 177.118 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.439 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.452 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- HRAM was moved out of the bus controller into `rtl/memory/hram.vhd`, a small
  synchronous single-port RAM with an explicit M9K RAM style attribute.
- Quartus now infers `hram:u_hram` as an `altsyncram` using one M9K block,
  128 words x 8 bits, instead of retaining HRAM as distributed registers and
  logic in the bus controller.
- The previous uninferred-RAM warning for HRAM is gone.
- Compared with the configurable bus/debug checkpoint, the full top dropped
  from 4,995 to 3,674 logic elements, saving 1,321 logic elements.
- Register use dropped from 1,965 to 941 registers, saving 1,024 registers.
- The cost is one additional M9K and 1,024 additional block-memory bits:
  179,200 bits / 23 M9Ks became 180,224 bits / 24 M9Ks.
- The bus controller hierarchy dropped from 1,870 logic cells and 1,210
  registers to 543 logic cells and 186 registers. The new `hram` hierarchy
  contributes 1,024 memory bits and zero logic cells.
- This optimization moves the design below the requested 4,600-LE target with
  meaningful margin. The project is still M9K-sensitive at 24 / 30 blocks, but
  logic is no longer the immediate blocker for the next first-playable slices.

## Initial WRAM/Echo-Backed OAM DMA Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-22

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 3,741 | 6,272 | 60% |
| Registers | 951 | 6,272 | 15% |
| Pins | 11 | 92 | 12% |
| Memory bits | 180,224 | 276,480 | 65% |
| M9Ks | 24 | 30 | 80% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 28.883 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 179.754 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.436 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.453 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- `bus_controller` now treats writes to `0xFF46` as the start of an initial
  OAM DMA transfer.
- This first slice supports WRAM and Echo RAM source pages
  `0xC000..0xDF9F` and `0xE000..0xFD9F`, which covers the important
  shadow-OAM-to-OAM path needed by simple games.
- The DMA engine copies 160 bytes into `0xFE00..0xFE9F` and holds
  `cpu_ready` low while the transfer is active.
- The implementation uses the existing WRAM and OAM M9K-backed memories. No new
  memory bits or M9K blocks were added.
- The current implementation is intentionally not a complete DMG OAM DMA model:
  ROM, cartridge RAM, VRAM, and HRAM source pages are not yet copied by this
  first slice, and the transfer is serialized through the existing registered
  WRAM read path rather than being exact 160-M-cycle behavior.
- `tb_bus_controller` now fills 160 bytes of WRAM, writes `0xC0` to `0xFF46`,
  waits through the `cpu_ready` stall, and verifies the copied OAM bytes.
- Compared with the HRAM M9K checkpoint, this costs 67 logic elements and 10
  registers, with unchanged block-memory and M9K usage. The bus controller
  hierarchy rises from 543 logic cells / 186 registers to 600 logic cells /
  196 registers.

## Initial Real JOYP Register Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-22

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 3,739 | 6,272 | 60% |
| Registers | 955 | 6,272 | 15% |
| Pins | 15 | 92 | 16% |
| Memory bits | 180,224 | 276,480 | 65% |
| M9Ks | 24 | 30 | 80% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 26.459 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 175.981 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.373 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.452 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- `bus_controller` now implements the real `0xFF00` JOYP register semantics:
  CPU-writable select bits 5 and 4, active-low button reads in bits 3..0, and
  bits 7..6 reading as one.
- Logical button inputs are active-high at the bus boundary. The bus maps the
  action group as A, B, Select, Start and the direction group as Right, Left,
  Up, Down.
- A selected button transition from released to pressed sets IF bit 4, giving
  the CPU an initial Joypad interrupt request path.
- `cpu_ppu_background_demo_top` maps the four verified physical `key_n` pins to
  A, B, Select, and Start. Direction inputs remain tied inactive in this top
  until the DIP/PS2 input path is assigned and debounced.
- Compared with the OAM DMA checkpoint, this keeps memory usage unchanged and
  changes the fitted result by -2 logic elements and +4 registers. The small
  logic decrease is a fitter optimization artifact after exposing the physical
  key pins; the meaningful cost is the four retained JOYP edge/state registers.

## Initial Window Rendering Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-22

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 3,809 | 6,272 | 61% |
| Registers | 955 | 6,272 | 15% |
| Pins | 15 | 92 | 16% |
| Memory bits | 180,224 | 276,480 | 65% |
| M9Ks | 24 | 30 | 80% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 28.253 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 176.395 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.445 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.452 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- `ppu_background_renderer` now supports the initial DMG Window path.
- Window is enabled by `LCDC(5)`, uses the tile map selected by `LCDC(6)`, and
  uses the DMG horizontal comparison `screen_x + 7 >= WX`.
- The Window fetch coordinates are derived from `screen_x + 7 - WX` and
  `screen_y - WY`; outside that region, the existing scroll-based background
  fetch path is preserved.
- `bus_controller` now exposes `WY` and `WX` to the PPU path, while preserving
  CPU read/write behavior at `0xFF4A` and `0xFF4B`.
- The implementation reuses the existing tile-map/tile-data fetch states and
  adds no RAM, FIFO, or M9K usage.
- Compared with the JOYP checkpoint, this costs 70 logic elements, 0
  registers, and no additional memory bits. This is acceptable for the
  first-playable target and keeps the design well below the 4,600-LE working
  target.

## DMG Sprite Priority Refinement Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-22

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 3,831 | 6,272 | 61% |
| Registers | 967 | 6,272 | 15% |
| Pins | 15 | 92 | 16% |
| Memory bits | 180,224 | 276,480 | 65% |
| M9Ks | 24 | 30 | 80% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 29.631 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 174.824 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.445 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.453 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- Sprite composition now applies the DMG OBJ-to-OBJ priority rule for the 10
  scanline candidates already produced by `ppu_oam_scan`.
- For overlapping nontransparent OBJ pixels, lower X coordinate wins.
- When X coordinates are equal, the earlier OAM candidate remains selected.
- BG/OBJ priority bit behavior is preserved: OBJ pixels marked behind BG are
  still hidden by nonzero BG/Window color IDs.
- The implementation keeps the serialized per-pixel candidate walk and adds a
  small selected-OBJ accumulator, avoiding a parallel 10-way sorter.
- Compared with the Window checkpoint, this costs 22 logic elements and 12
  registers, with unchanged memory and M9K usage.

## PS/2 Joypad Input Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-22

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 3,887 | 6,272 | 62% |
| Registers | 994 | 6,272 | 16% |
| Pins | 17 | 92 | 18% |
| Memory bits | 180,224 | 276,480 | 65% |
| M9Ks | 24 | 30 | 80% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 1 | 2 | 50% |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C, PLL VGA clock | 29.313 ns |
| Setup, slow 1200 mV 85 C, PLL CPU clock | 173.511 ns |
| Hold, slow 1200 mV 85 C, PLL CPU clock | 0.432 ns |
| Hold, slow 1200 mV 85 C, PLL VGA clock | 0.453 ns |
| Minimum pulse width, `clk_50mhz` | 9.858 ns |

TimeQuest reports the design as fully constrained for setup and hold.

Notes:

- `ps2_keyboard_joypad` adds a compact PS/2 Set-2 receiver with make/break
  tracking for `W/A/S/D`, `J/K`, Space, and Enter.
- The current hardware top now maps PS/2 direction keys to the real JOYP
  direction group and ORs PS/2 action keys with the verified `key_n` action
  buttons.
- `ps2_clk` and `ps2_data` are synchronized into the CPU clock domain and
  constrained as asynchronous input false paths.
- The module costs 59 hierarchy logic cells and 27 registers, with no RAM,
  M9K, multiplier, or PLL usage.
- Compared with the sprite-priority checkpoint, the full fitted top costs 56
  additional logic elements and 27 registers, plus two input pins.

## Isolated SDRAM Controller Simulation Slice

Canonical project: `gameboy_core`

Top-level entity: `cpu_ppu_background_demo_top`

Report date: 2026-05-22

This slice adds `rtl/memory/sdram_controller.vhd` and its ModelSim testbench,
but does not instantiate the controller in the current top-level design yet.
The fitted Game Boy top therefore remains at the PS/2 joypad checkpoint
resource level until a dedicated SDRAM hardware test top is introduced.

Validated behavior:

- reset/init wait;
- precharge-all command;
- two initial auto-refresh commands;
- mode-register load;
- single-word write;
- single-word read;
- byte-enable masking through DQM;
- periodic refresh while idle.

Resource impact on current fitted top:

- no change while uninstantiated: the current top remains at 3,887 logic
  elements, 994 registers, 180,224 memory bits, and 24 M9K blocks;
- no additional M9K usage;
- no SDRAM pins exposed by the active top yet.

Next measurement point:

- synthesize a dedicated SDRAM hardware test top after the SDRAM pins are
  enabled and the controller is connected to a deterministic write/read
  checker.

## SDRAM Hardware Bring-Up Top

Canonical project: `gameboy_core`

Top-level entity: `sdram_test_top`

Report date: 2026-05-23

This checkpoint adds a dedicated physical SDRAM test top and keeps it separate
from the active Game Boy visual top. The test top exposes the SDRAM pins,
initializes the memory, performs deterministic write/read checks, verifies
lower-byte DQM masking, and reports status through LEDs.

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic elements | 243 | 6,272 | 4% |
| Registers | 148 | 6,272 | 2% |
| Pins | 44 | 92 | 48% |
| Memory bits | 0 | 276,480 | 0% |
| M9Ks | 0 | 30 | 0% |
| 9-bit multiplier elements | 0 | 30 | 0% |
| PLLs | 0 | 2 | 0% |

Timing summary for the 50 MHz bring-up clock:

| Check | Worst Slack |
| --- | ---: |
| Setup, slow 1200 mV 85 C | 13.950 ns |
| Hold, slow 1200 mV 85 C | 0.453 ns |
| Minimum pulse width, `clk_50mhz` | 9.741 ns |

TimeQuest reports the SDRAM test top as fully constrained for internal setup
and hold. The SDRAM board-level I/O constraints in
`constraints/sdram_test_timing.sdc` are intentionally temporary false paths for
first functional bring-up. They must be replaced by proper external SDRAM I/O
timing constraints before the SDRAM path becomes part of the cartridge bus.

Notes:

- `sdram_controller` now exposes `cmd_accept`, allowing a client FSM to advance
  only when a command is actually captured. This avoids lost write/read
  requests when an automatic refresh has priority.
- The external SDRAM clock is driven inverted relative to the controller clock
  so registered command/address/data outputs settle before the memory samples
  them during the initial 50 MHz hardware bring-up.
- `scripts/build_sdram_test.tcl` temporarily switches the project top to
  `sdram_test_top`, applies the dedicated SDRAM pins and timing file, runs the
  compile, then restores the main QSF so the normal Game Boy top does not keep
  unused SDRAM pin assignments.
- The active `cpu_ppu_background_demo_top` remains at the previous PS/2 joypad
  resource level until the SDRAM path is integrated into the system bus.
