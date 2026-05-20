# Design Decisions

## VHDL Standard

The project targets VHDL-1993 because Quartus II 13.0 SP1 and the bundled
ModelSim-Altera flow have limited VHDL-2008 support. Code should use only:

- `ieee.std_logic_1164`
- `ieee.numeric_std`

Non-standard Synopsys packages such as `std_logic_unsigned` and
`std_logic_arith` are intentionally avoided.

## Reset Strategy

External reset is active-low from the board. Top-level modules convert it to an
active-high internal reset and synchronize it in the relevant clock domain.
Subsystem RTL uses synchronous active-high reset where a reset is needed.

PLL asynchronous reset inputs are driven through named internal signals instead
of inline expressions in port maps. This keeps top-level files compatible with
strict VHDL-1993 tools.

## Framebuffer First

The project implements the framebuffer and VGA read path before the PPU. This
provides an early hardware-visible milestone and establishes the clock-domain
boundary between the future Game Boy pixel producer and VGA output.

The framebuffer stores native Game Boy pixels:

- 160x144 pixels.
- 2 bits per pixel.
- 46,080 total bits.
- Expected implementation: Cyclone IV M9K block RAM.

## CPU Before Real PPU

The project grows the CPU, memory map, timer, and timing model before starting
the real PPU. A Game Boy PPU depends on CPU-visible register timing, interrupt
behavior, and bus ownership. Starting the PPU too early would make later visual
failures ambiguous because a bad frame could come from the PPU, CPU timing, the
timer, or the bus.

The rule followed by the project was:

1. broad CPU behavior first;
2. realistic bus and memory contracts next;
3. timing refinement before the real PPU;
4. tile-based PPU work only after those shared contracts are stronger.

That boundary has now been crossed. The first PPU slice is deliberately small:
real VRAM, a demo VRAM loader, and a background-only renderer that reads tile
data plus tile map entries before writing the existing framebuffer. This keeps
the first PPU failure surface narrow while still exercising the real
video-memory direction of travel.

The next integration step keeps the isolated demo top as a baseline, but adds a
second top where the CPU writes deterministic tile data and tile-map bytes into
VRAM before the renderer is allowed to start. The explicit start marker at debug
I/O address `0xFF80` keeps the first CPU/PPU interaction controlled and prevents
an incomplete VRAM image from being rendered during bring-up.

That controlled top has now been validated on hardware. The first visible image
is deliberately simple: a centered Game Boy viewport with an alternating
white/checkerboard first row. Its value is architectural rather than cosmetic:
it proves that the CPU can author VRAM, the PPU can consume it, and the existing
framebuffer/VGA path still behaves correctly after the subsystems are joined.

## Explicit Test Program Boundary

The first visual integrations started with ROM contents embedded inside
`bus_controller` because that kept early bring-up small. Once CPU-authored VRAM
became a real system checkpoint, that shortcut stopped being a good boundary:
changing a test scene should not require editing the memory-map owner.

The bus now receives ROM data through a port, while dedicated ROM modules hold
the smoke and CPU/PPU demonstration programs. This adds no measurable fitter
cost in the current top, but it improves the long-term structure in two ways:

1. the bus is closer to its eventual role with cartridge or loader-backed ROM;
2. future visual test programs can evolve independently from address decoding.

## SCX/SCY Before Scanline Structure

The first PPU-visible LCD behavior is background scrolling. The current renderer
adds the 8-bit `SCX` and `SCY` values to the visible pixel coordinates before
selecting tile-map entries, tile rows, and pixel bits. Because the arithmetic is
kept at 8 bits, wraparound naturally follows the 256x256 background plane.

This was intentionally implemented before the scanline scheduler. It proved the
register path and tile-addressing math with a tiny resource cost, allowing the
next timing refactor to focus on when pixels are produced rather than on whether
the correct background coordinate is selected.

## Scanline Boundary Before Dot-Accurate PPU Modes

The background renderer now advances through explicit scanline boundaries and
exposes `current_line`, `line_active`, and `line_done`. This is deliberately not
a complete DMG PPU mode implementation yet: it does not model Mode 2, Mode 3,
Mode 0, VBlank, STAT interrupts, window, sprites, or OAM timing.

The decision is to split the PPU timing problem into smaller hardware-safe
steps:

1. preserve the already validated CPU-to-VRAM-to-PPU visual path;
2. make visible line progression observable and testable;
3. connect that line progression to LY/STAT in a later slice;
4. only then refine the renderer toward dot-level PPU modes.

This keeps the implementation compatible with the tight EP4CE6 resource budget:
the scanline step added only a small FSM cost and no additional memory blocks.

## Minimal LY/STAT Before Full PPU Modes

After the renderer exposed visible scanlines, the bus began reporting `LY` from
the PPU line signal and computing a minimal `STAT` read value. The writable
interrupt-select bits are preserved, the coincidence bit is derived from
`LY=LYC`, and the mode field is provisional: Mode 3 while the background line is
active, Mode 0 otherwise.

This is not intended to pass PPU timing tests yet. Its purpose is to establish
the CPU-visible register contract before introducing a more expensive dot-level
scheduler. Keeping the first `STAT` implementation simple gives the next slice a
clear target: replace the provisional mode source with real Mode 2, Mode 3,
Mode 0, and Mode 1 timing while preserving the same bus-facing register shape.

## Initial PPU Mode Scheduler Before Interrupts

The provisional `STAT` mode source has now been replaced by an explicit mode
output from the background renderer. The bus no longer guesses the mode from a
generic line-active signal; it routes the renderer's `ppu_mode` field directly
into `STAT`.

This scheduler is intentionally line-level, not dot-accurate. It reports:

- Mode 2 at visible-line start;
- Mode 3 while the background renderer produces the line;
- Mode 0 at visible-line end;
- Mode 1 while the renderer advances through VBlank lines `144..153`.

The design choice is to make the CPU-visible PPU phase observable before adding
interrupt side effects. The next slice can now use one clear source of truth for
VBlank and STAT interrupt requests, while later work can refine the duration of
each mode toward real DMG dot timing.

## Line-Level PPU Interrupts Before Dot Timing

The first PPU interrupt slice is implemented in the bus controller because that
block already owns the CPU-visible `IF`, `IE`, `STAT`, `LY`, and `LYC`
registers. The PPU provides the current line and mode; the bus turns those into
interrupt request flags.

The current behavior is deliberately edge-detected:

- VBlank requests IF bit 0 when the line-level scheduler enters Mode 1 at
  `LY=144`;
- enabled STAT sources request IF bit 1 when the combined STAT condition rises;
- acknowledging an interrupt while the same condition remains active does not
  immediately set the same IF bit again.

This is the right level for the current renderer because the scheduler itself is
still line-level. The next accuracy step should refine when modes begin and end,
not duplicate interrupt logic in several places. Once the PPU moves toward
dot-level timing, the same bus-facing IF/STAT contract can stay in place while
the source timing becomes more faithful.

## Serial-First CPU Validation

CPU validation uses Blargg-style serial output before relying on the future PPU.
The serial debug path at `0xFF01` and `0xFF02` is intentionally a low-cost test
hook, not a complete serial peripheral. It lets simulation determine whether a
real test ROM reached `Passed` without requiring a display subsystem to be
correct at the same time.

This keeps CPU regressions narrow and makes failure diagnosis much faster during
M3 and early timing work.

## Timing Before Integration

Passing the individual `cpu_instrs` ROMs proves broad functional correctness, but
it does not prove cycle accuracy. Before the real PPU depends on the CPU bus, the
design must move through:

- `instr_timing` (currently passing);
- `mem_timing` (currently passing);
- `mem_timing-2` (currently passing);
- `interrupt_time` (currently passing);
- `halt_bug.gb` (currently passing).

This is the bridge from "the CPU computes the right result" to "the CPU occupies
the bus at the right time," which matters for a hardware reimplementation.

## Fetch Fast-Path Discipline

The timing bring-up uses fetch-stage fast paths for instruction families that
must not pay an extra standalone decode cycle. This optimization is kept narrow
and evidence-driven:

- direct opcode helper predicates are preferred when fetch dispatch needs a
  memory-path distinction that generic decode metadata does not preserve safely;
- `S_DECODE` should retain only behavior that still needs a real extra cycle or
  a meaningful fallback path;
- every fast-path cleanup must rerun both the local timing probe and Blargg ROMs
  that exercise WRAM copy, ALU, and control-flow behavior.

An attempted generic `DEC_CLASS_LD_MEM` routing broke the WRAM code-copy path in
the Blargg shell, while small shared opcode predicates kept the behavior correct
and reduced fitter usage. A lower-level explicit classification is the better
hardware abstraction when it preserves a real timing or datapath distinction.

The same rule now applies to unconditional control flow. `JP nn`, `CALL nn`,
`RET`, and `RETI` need explicit fetch-stage routing plus internal M-cycle states
so the CPU does not accidentally complete them as decode-only shortcuts. This is
especially visible in Blargg `instr_timing`, because that ROM uses a generated
`JP instr_end` sequence as part of its own timing harness. If unconditional
control flow is off by one M-cycle, many unrelated opcodes appear wrong.

Timer bring-up also keeps a documented phase assumption: the current M-cycle CPU
model initializes the timer divider with a small phase offset so the Blargg
timing harness can calibrate before measuring opcodes. This is a simulation and
bring-up alignment point, not the final fine-grained T-cycle timer model.

That phase is now an explicit generic on the timer block. This keeps the
assumption visible in simulation scripts and prevents silent magic constants
from spreading through the codebase. The default value remains selected for the
current M-cycle model.

Blargg `instr_timing.gb` also exposed a CPU/timer observation issue: individual
opcode fetch-to-fetch probes showed correct M-cycle counts, while the real ROM
still measured several opcodes one cycle off through TIMA. The adopted model is
that CPU reads observe the value visible at the end of the current M-cycle bus
access. For normal divider-edge TIMA increments, `tima_read` therefore exposes
the post-edge value. The overflow path remains delayed so TIMA still holds
`0x00` before the later TMA reload and interrupt pulse. This allowed
`instr_timing.gb` to reach `Passed` without adding fake cycles to otherwise
correct opcode bodies.

The same model now carries the first memory timing layer: Blargg
`mem_timing` individual ROMs for read, write, and read-modify-write access
placement all reach `Passed`, and the aggregate `mem_timing.gb` reaches
`Passed` as well. This means the current bus contract is good enough for the
instruction families covered by that suite.

`mem_timing-2` uses Blargg's memory status protocol at cartridge RAM
`0xA000..0xA004` rather than relying on link-port serial output. The ROM runner
therefore observes the documented signature at `0xA001..0xA003` and the final
status byte at `0xA000`. With that runner support, the `mem_timing-2`
individual and aggregate ROMs also reach `Passed`. `interrupt_time.gb` and
`halt_bug.gb` now reach `Passed` as well, so the local Blargg timing ladder is
complete enough to justify the next architecture step: checkpoint the CPU/timing
phase before the real PPU depends on it.

## VGA Pinout Caution

Public RZ-EasyFPGA A2.2 pin references commonly list VGA as scalar `VGA_R`,
`VGA_G`, and `VGA_B` pins rather than multi-bit DAC buses. The internal video
pipeline keeps 3-bit RGB channels so color depth can be adapted later, but the
board-level top should map only the physically available pins unless the exact
board schematic confirms a wider resistor DAC.

## Resource Discipline

The EP4CE6 has only 6,272 logic elements and 276,480 block RAM bits. Large
lookup tables and broad control abstractions should be introduced only when they
replace real complexity. Early milestones prioritize correctness, but every
meaningful RTL slice is still synthesized and measured so resource drift is
visible before it becomes architectural debt.

The CPU/timing checkpoint uses 4,283 logic elements, or 68% of the device. The
first real VRAM slice already raises memory use to 177,152 bits and 22 M9Ks, so
later PPU, DMA, SDRAM, and optional APU work must continue to favor shared
datapaths, inferred RAM, and incremental integration.
