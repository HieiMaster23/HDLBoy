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
