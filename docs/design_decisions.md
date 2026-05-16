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
