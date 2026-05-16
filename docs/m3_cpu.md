# M3 CPU Implementation

This document tracks the first incremental implementation slice of the Sharp
LR35902 CPU core. The current goal is not full Game Boy compatibility yet; it is
a synthesizable, multi-cycle foundation that can grow toward Blargg CPU test ROM
coverage without being rewritten.

## Strategy

The CPU is split into four RTL modules:

- `rtl/cpu/cpu.vhd`: top-level CPU sequencer, memory bus control, PC/SP updates,
  stack sequencing, interrupt dispatch, and HALT bookkeeping.
- `rtl/cpu/alu.vhd`: combinational 8-bit ALU for the first arithmetic and logic
  subset, including Z/N/H/C flag generation.
- `rtl/cpu/registers.vhd`: synchronous A/F/B/C/D/E/H/L, SP, and PC register
  file with combinational register reads.
- `rtl/cpu/decoder.vhd`: combinational opcode decoder for the implemented M3
  subset.

The CPU uses explicit fetch, decode, immediate-read, memory-read, memory-write,
push, pop, call, return, and halt states. This is intentionally multi-cycle so
future memory wait states, bus arbitration, and PPU/CPU contention can be added
without changing the architectural model.

## Implemented Instruction Subset

Basic and load instructions:

- `NOP`
- `LD r,n` for B, C, D, E, H, L, A
- `LD r,r`
- `LD r,(HL)` for B, C, D, E, H, L, A
- `LD (HL),r` for B, C, D, E, H, L, A
- `LD rr,nn` for BC, DE, HL, SP
- `LD A,(BC)`, `LD A,(DE)`, `LD (BC),A`, `LD (DE),A`
- `LD A,(HL+)`, `LD A,(HL-)`, `LD (HL+),A`, `LD (HL-),A`
- `LD (HL),n`
- `LDH (n),A`
- `LDH A,(n)`
- `LDH (C),A`
- `LDH A,(C)`
- `LD (nn),A`
- `LD A,(nn)`
- `LD (nn),SP`
- `LD SP,HL`
- `LD HL,SP+e`

ALU and flag instructions:

- `INC r`
- `DEC r`
- `INC (HL)`
- `DEC (HL)`
- `ADD A,r`
- `SUB r`
- `AND A,r`
- `OR A,r`
- `XOR A,r`
- `CP r`
- `ADC A,r`
- `SBC A,r`
- `ADD/ADC/SUB/SBC/AND/XOR/OR/CP A,n`
- `ADD A,(HL)`
- `ADC A,(HL)`
- `SUB (HL)`
- `SBC A,(HL)`
- `AND A,(HL)`
- `OR A,(HL)`
- `XOR A,(HL)`
- `CP (HL)`
- `DAA`
- `RLCA`, `RRCA`, `RLA`, `RRA`
- `CPL`, `SCF`, `CCF`
- CB-prefixed register operations for RLC/RRC/RL/RR/SLA/SRA/SWAP/SRL,
  BIT, RES, and SET.
- CB-prefixed `(HL)` operations for RLC/RRC/RL/RR/SLA/SRA/SWAP/SRL,
  BIT, RES, and SET.
- `INC rr`, `DEC rr`, and `ADD HL,rr`
- `ADD SP,e`

Control flow and stack:

- `JP nn`
- `JP cc,nn`
- `JP HL`
- `JR e`
- `JR cc,e`
- `CALL nn`
- `CALL cc,nn`
- `RET`
- `RET cc`
- `RETI`
- `RST 00h/08h/10h/18h/20h/28h/30h/38h`
- `PUSH BC/DE/HL/AF`
- `POP BC/DE/HL/AF`

Control base:

- `HALT` enters a halt state and exits when an interrupt is pending.
- `DI` clears IME.
- `EI` uses delayed IME enable after the following completed instruction.
- Initial interrupt servicing accepts pending `IE & IF` bits when IME is set,
  clears IME, pushes PC, jumps to the selected vector, and emits
  `interrupt_ack`.
- `STOP` currently consumes its padding byte and continues execution. This is a
  bring-up placeholder for Blargg aggregate flow, not a real low-power STOP
  implementation.

## Current Limitations

- Interrupt servicing is functional enough for `02-interrupts.gb`, but the
  exact LR35902 interrupt timing still needs refinement.
- Instruction timing is still an incremental approximation. The CPU has a
  `mem_ready` input for registered memory and wait-state integration, but it is
  not yet fully cycle-accurate against the LR35902.
- The timer has been extracted into `rtl/io/timer.vhd` and now implements
  DIV/TIMA/TMA/TAC, TAC-selected divider edges, TIMA reload delay, and a timer
  interrupt pulse. Its divider step is still adapted to the current CPU
  execution granularity until instruction timing is refined.
- The exact HALT bug behavior is not implemented yet.
- Real STOP behavior is not implemented yet.

## Flags

The ALU exposes flags as `ZNHC` in a 4-bit vector. The F register stores these
bits in `F[7:4]`; `F[3:0]` is always written as zero.

- Z is set when the 8-bit result is zero.
- N is set for subtract/compare/decrement operations and cleared for
  add/logical/increment operations.
- H is set on nibble carry for ADD/INC and nibble borrow for SUB/CP/DEC.
- C is set on 8-bit carry for ADD and 8-bit borrow for SUB/CP.
- INC and DEC preserve C.
- CP updates flags like SUB but does not write A.
- DAA adjusts A after BCD add/subtract using the previous N/H/C flags, clears H,
  preserves N, updates Z, and sets C when the decimal correction crosses 0x99.

## Tests

Current ModelSim scripts:

- `sim/modelsim/run_cpu_alu.do`
- `sim/modelsim/run_cpu_registers.do`
- `sim/modelsim/run_cpu_decoder.do`
- `sim/modelsim/run_cpu_smoke.do`
- `sim/modelsim/run_cpu_rom_runner.do`
- `sim/modelsim/run_cpu_blargg_01.do`
- `sim/modelsim/run_cpu_blargg_02.do`
- `sim/modelsim/run_cpu_blargg_03.do`
- `sim/modelsim/run_cpu_blargg_04.do`
- `sim/modelsim/run_cpu_blargg_05.do`
- `sim/modelsim/run_cpu_blargg_06.do`
- `sim/modelsim/run_cpu_blargg_07.do`
- `sim/modelsim/run_cpu_blargg_08.do`
- `sim/modelsim/run_cpu_blargg_10.do`
- `sim/modelsim/run_cpu_blargg_09.do`
- `sim/modelsim/run_cpu_blargg_11.do`
- `sim/modelsim/run_cpu_instr_timing.do`
- `sim/modelsim/run_cpu_interrupt_time.do`
- `sim/modelsim/run_cpu_halt_bug.do`
- `sim/modelsim/run_cpu_timing_probe.do`
- `sim/modelsim/run_timer.do`
- `sim/modelsim/run_cpu_all.do`
- `sim/modelsim/run_cpu_integration_top.do`
- `sim/modelsim/run_cpu_video_smoke_top.do`

The smoke program verifies a small instruction sequence covering immediate
loads, HL memory access, ALU flags, unconditional jump, stack transfer,
subroutine call/return, `(HL)` read-modify-write execution, and relative branch
looping.

`tb_cpu_rom_runner` now loads a real Game Boy ROM image up to 64 KiB with a
VHDL simulation-only binary file reader. The default target is
`gb-test-roms-master/cpu_instrs/individual/06-ld r,r.gb`.

The runner provides a full 64 KiB simulation memory, captures serial output
through the Game Boy `0xFF01`/`0xFF02` convention, stubs basic I/O registers,
and advances `LY`/`DIV` enough for Blargg's shell delay loops to complete
without a PPU. It stops when the serial transcript contains `Passed` or
`Failed`, or on timeout/unsupported opcode. `G_TIMEOUT_CYCLES` can be raised for
long ROMs without changing the default runner behavior. `G_VERBOSE_SERIAL` can
be disabled for long aggregate runs to avoid per-byte log overhead. Unsupported
opcode failures now emit a small fetch ring buffer so control-flow regressions
are easier to localize from the transcript alone.

Current Blargg bring-up result:

- `cpu_instrs/individual/01-special.gb`: `Passed` via serial transcript using
  `G_TIMEOUT_CYCLES=50000000`.
- `cpu_instrs/individual/02-interrupts.gb`: `Passed` via serial transcript
  using `G_TIMEOUT_CYCLES=30000000`.
- `cpu_instrs/individual/06-ld r,r.gb`: `Passed` via serial transcript.
- `cpu_instrs/individual/04-op r,imm.gb`: `Passed` via serial transcript.
- `cpu_instrs/individual/08-misc instrs.gb`: `Passed` via serial transcript.
- `cpu_instrs/individual/05-op rp.gb`: `Passed` via serial transcript.
- `cpu_instrs/individual/03-op sp,hl.gb`: `Passed` via serial transcript.
- `cpu_instrs/individual/07-jr,jp,call,ret,rst.gb`: `Passed` via serial transcript.
- `cpu_instrs/individual/09-op r,r.gb`: `Passed` via serial transcript using
  `G_TIMEOUT_CYCLES=25000000`.
- `cpu_instrs/individual/10-bit ops.gb`: `Passed` via serial transcript using
  `G_TIMEOUT_CYCLES=50000000`.
- `cpu_instrs/individual/11-op a,(hl).gb`: `Passed` via serial transcript using
  `G_TIMEOUT_CYCLES=50000000`.

Latest timer checkpoint validation:

- `run_timer.do`: `Passed`.
- `run_bus_controller.do`: `Passed`.
- `run_cpu_blargg_02.do`: `Passed` with the extracted timer block.
- Fast individual Blargg regression rerun in this slice:
  `03-op sp,hl.gb`, `04-op r,imm.gb`, `05-op rp.gb`, `06-ld r,r.gb`, and
  `08-misc instrs.gb` all reached `Passed`.
- Long individual regression started with `01-special.gb`, which also reached
  `Passed` with the extracted timer block.
- `02-interrupts.gb` also reached `Passed` again in the long regression pass,
  confirming the extracted timer still drives the initial interrupt flow.
- `07-jr,jp,call,ret,rst.gb` reached `Passed` again in the long regression
  pass, keeping control-flow and stack sequencing covered after the timer work.
- `09-op r,r.gb` reached `Passed` again in the long regression pass, keeping
  the register-to-register ALU path covered after the timer work.
- `10-bit ops.gb` reached `Passed` again in the long regression pass, keeping
  CB register bit operations covered after the timer work.
- `11-op a,(hl).gb` reached `Passed` again in the long regression pass, keeping
  indirect `(HL)` ALU and CB memory operations covered after the timer work.
- `run_cpu_video_smoke_top.do` reached `Passed`, keeping CPU-to-bus-to-
  framebuffer integration covered after the timer work.
- Quartus full compilation passed on 2026-05-15 for `cpu_video_smoke_top` with
  4,157 / 6,272 logic elements used (66%), 111,616 memory bits used (40%), and
  closed timing on all constrained clocks.
- `cpu_instrs.gb` aggregate is supported by the 64 KiB runner and advanced past
  the previous STOP-related block. It reached at least `29:ok` before the run
  was stopped for wall-clock time, so it remains a long checkpoint test rather
  than the daily regression path.

## Hardware Integration Harness

The current Quartus top-level is `rtl/top/cpu_integration_test_top.vhd`. It
connects the CPU to:

- a small ROM implemented as a VHDL address decode function;
- sparse writable locations for `0xC000`, `0xFF80`, `0xFF81`, `0xFFFC`, and
  `0xFFFD`;
- LED output at memory-mapped address `0xFF80`;
- pass/fail status at memory-mapped address `0xFF81`;
- a four-digit active-low seven-segment display driver.

The ROM program exercises the currently implemented instruction subset:

- `LD SP,nn`
- `LD HL,nn`
- `LD r,n`
- `LD r,r`
- `LD A,(HL)`
- `LD (HL),A`
- `INC r`
- `DEC r`
- `ADD A,r`
- `SUB r`
- `AND A,r`
- `OR A,r`
- `XOR A,r`
- `CP r`
- `JP/JR`-style control flow via the existing `JR e` loop
- `CALL nn`
- `RET`
- `PUSH BC`
- `POP DE`

The checker validates the CPU-written LED checkpoint sequence `1, 4, 8, 9, D`,
the stored WRAM byte at `0xC000`, stack restoration, and key register values
after the program completes. If all checks pass, the seven-segment display shows
`1234`. If a check fails, the display shows `EEEE` and all LEDs are forced on.

The seven-segment segment pins are based on public RZ-EasyFPGA A2.2 references.
Hardware observation showed the digit-enable order was reversed from that
reference on this board, so `digit_n[*]` is mapped in reverse order in the QSF.

## CPU-to-Framebuffer Smoke Test

The current hardware-facing top is `rtl/top/cpu_video_smoke_top.vhd`. It keeps
the CPU subset connected to the M2 framebuffer and VGA path:

- ROM is implemented in `rtl/memory/bus_controller.vhd` as a temporary internal
  smoke-test ROM.
- A temporary framebuffer-mapped window starts at `0x8000` and stops before
  WRAM, so CPU smoke writes do not conflict with the DMG WRAM range.
- A resource-limited WRAM bring-up page is present at `0xC000..0xC03F`, with
  echo mirror behavior at `0xE000..0xE03F`. This is intentionally small until
  the CPU/bus contract supports registered RAM reads or wait states.
- Debug I/O registers at `0xFF80` and `0xFF81` drive LEDs and pass/fail status.
- HRAM is present at `0xFF80..0xFFFE`; the two debug locations are a temporary
  overlay for the smoke test.
- IF is present at `0xFF0F`, and IE is present at `0xFFFF`; their lower five
  bits feed the CPU interrupt input ports.
- The CPU `interrupt_ack` and `interrupt_vector` outputs feed the bus
  controller so the serviced IF bit can be cleared.
- The initial shared timer block raises the Timer IF bit through the bus
  controller. It is closer to DMG behavior than the old stub, but final timing
  accuracy depends on the later instruction-timing slice.
- Basic I/O stubs are present for JOYP, Serial, Timer registers, LCDC/STAT,
  scroll/window registers, DMA, and palette registers. They are placeholders
  for future timer, joypad, and PPU ownership.
- The CPU writes 64 black pixels into the framebuffer, then writes pass code
  `0xA5`.
- The top-level checker shows `1234` on the seven-segment display when the
  expected framebuffer writes and pass code complete.

`tb_cpu_video_smoke_top` verifies the external contract in simulation: final
LED checkpoint, seven-segment scan of `1234`, and active black/white VGA
output. It intentionally avoids hierarchical references so the testbench stays
portable across ModelSim-Altera and Quartus II 13.0 SP1 flows.

`tb_cpu_video_bus_controller` verifies the CPU-facing contract directly: it
checks exactly 64 framebuffer writes, each expected framebuffer address, black
pixel data value `3`, final LED checkpoint `D`, pass status, and display value
`1234`.

`tb_bus_controller` verifies direct memory-map behavior for ROM reads, the
initial WRAM page, echo mirror behavior, HRAM read/write, IF, IE, I/O stub
readbacks, the debug LED overlay, the framebuffer write port, and the serial
debug transfer pulse.

## Serial Debug Stub

The bus controller includes a simulation-observable serial debug path that is
intended to match the convention used by many Game Boy test ROMs:

- Writes to `0xFF01` update the SB data register.
- Writes to `0xFF02` update the SC control register.
- If a write to `0xFF02` has bit 7 set, `serial_debug_valid` pulses for one
  CPU clock and `serial_debug_data` exposes the current SB byte.

This is not a complete serial peripheral. It is a low-cost test hook for
Blargg-style output capture before implementing the real serial link timing.

## Blargg Preparation

The ROM runner is now the primary CPU validation path. The next implementation
slices should:

1. Keep `cpu_instrs.gb` aggregate as a long optional checkpoint test. The
   individual ROMs remain the official day-to-day regression.
2. Move into timing-focused validation with `instr_timing`, then `mem_timing`,
   `interrupt_time`, and `halt_bug.gb`.
3. Refine exact interrupt timing, EI/HALT edge cases, STOP behavior, and the
   HALT bug.
4. Keep the memory-map/bus-controller harness aligned with registered memory
   reads and future wait states.

## Timing-Fidelity Bring-Up

The first timing-specific slice is now in place:

- `tb_cpu_timing_probe` is a self-checking micro-program that verifies a small
  representative set of M-cycle counts:
  `NOP`, `LD B,n`, `LD BC,nn`, `LD (BC),A`, `LD A,(BC)`, `RLCA`,
  `LD (nn),SP`, `DAA`, `CPL`, `SCF`, `CCF`, `DI`, `LDH (n),A`,
  `LD (nn),A`, `JR e`, and taken/not-taken `JR cc,e`.
- `cpu.vhd` now performs fetch-stage fast paths for the first instruction
  families that must not spend an extra standalone decode cycle:
  `NOP`, register-only `LD r,r`, register-only `INC/DEC r`, register-only ALU
  ops, immediate register loads, 16-bit immediate loads, immediate ALU ops,
  indirect pair loads/stores, accumulator rotates, single-cycle flag/control
  ops, `LD (nn),SP`, `DI`, `LDH (n),A`, `LDH A,(n)`, `LD (nn),A`, and
  `LD A,(nn)`.
- Conditional relative branches now use distinct paths: not-taken `JR cc,e`
  completes in 2 M-cycles, while taken `JR cc,e` uses `S_JR_TAKEN` to preserve
  the required third cycle.
- Blargg `instr_timing.gb` now reaches `Passed` through the real ROM runner.
  The final fix for this checkpoint was not an opcode-specific cycle change,
  but an alignment of the CPU-visible TIMA read value with the end of the
  current M-cycle bus model.

The follow-up control refactor is now complete for this slice:

- register-addressed `LD` memory routing is centralized through small opcode
  helper predicates shared by fetch and decode;
- register-only `LD r,r`, `INC/DEC r`, and `ALU r` execution bodies were removed
  from the fallback decode path because those instructions are already executed
  in the fetch fast path;
- duplicated one-cycle accumulator rotate and flag-control execution bodies were
  also removed from `S_DECODE`;
- a rejected intermediate version routed `DEC_CLASS_LD_MEM` from generic decoder
  metadata alone, but it broke the WRAM copy flow used by Blargg ROMs. The final
  version keeps direct opcode groups because they preserve the required fetch
  dispatch distinction.

This remains incremental bring-up rather than a blanket FSM rewrite. The
refactor reduced the fitter result from 4,511 to 4,268 logic elements while
preserving the expanded timing coverage and the existing regression set.

## Next Code Step

The timing-fidelity phase now has a first real ROM checkpoint: Blargg
`instr_timing.gb` reaches `Passed`. The main fixes from that phase were:

- the timer reset phase was aligned with the current M-cycle CPU model so the
  Blargg timing harness can leave its initial timer calibration path;
- unconditional `JP nn` now keeps its fourth M-cycle instead of completing
  directly after the high immediate byte;
- unconditional `CALL nn` now uses the same internal pre-push M-cycle as taken
  conditional calls;
- unconditional `RET` and `RETI` now keep their fourth M-cycle after the high
  return-address read;
- `tb_cpu_timing_probe` now covers `JP nn`, `CALL nn`, and `RET` in addition to
  the previous conditional branch and CB-prefix cases;
- `TIMA` reads now expose the value visible after a normal divider-edge
  increment at the end of the current M-cycle, while the overflow reload delay
  remains visible as a separate delayed event.

The next slice should keep the same discipline: use Blargg ROMs as the
acceptance target, use local probes only to localize failures already reported
by those ROMs, make the smallest hardware change, and rerun the quick
regressions before moving to another timing ROM.

The latest diagnostic slice expanded that probe before changing the CPU again:

- `rtl/io/timer.vhd` now exposes the divider reset phase as
  `G_DIV_COUNTER_RESET`. The default remains `4`, and the `instr_timing` script
  passes that value explicitly so the current phase assumption is visible.
- A short phase sweep showed that reset phases `0`, `8`, and `12` do not reach
  the opcode table reliably in the current model, while phase `4` still reaches
  opcode timing output.
- `TIMA` reads now expose the post-divider-edge increment value for normal TIMA
  increments in the current M-cycle bus model. The overflow path was kept
  delayed, so `tb_timer` still verifies that TIMA holds `0x00` before the later
  TMA reload and interrupt pulse.
- `tb_cpu_timing_probe` now also covers early opcode families reported by
  `instr_timing`: `INC BC`, `DEC BC`, `LD (HL+),A`, `LD A,(HL+)`,
  `LDH A,(n)`, `LD A,(nn)`, and `LD SP,HL`.

Those probe additions pass, and the real `instr_timing.gb` result confirmed the
important conclusion: the early opcode differences were caused by the
CPU/timer observation boundary, not by the individual opcode bodies.

A dedicated debug-only probe now exists for that boundary:

- `tb_cpu_timer_blargg_probe` runs a small CPU program against the shared timer
  and uses Blargg-style `start_timer`/`stop_timer` loops.
- This probe is not an acceptance test and does not replace Blargg ROMs. It is a
  localization tool for understanding failures already reported by Blargg.
- Current diagnostic result after the timer read visibility fix: `NOP` measures
  as `1`, and `LD BC,nn` measures as `3`, matching Blargg's expectation.
- The same `LD BC,nn` instruction still measures as `3` in the direct
  fetch-to-fetch CPU timing probe, so the remaining issue is likely in the
  CPU/timer measurement boundary rather than the basic immediate-load FSM body.

Current validation for this checkpoint:

- `run_cpu_instr_timing.do`: `Passed`.
- `run_cpu_mem_timing_01.do`: `Passed`.
- `run_cpu_mem_timing_02.do`: `Passed`.
- `run_cpu_mem_timing_03.do`: `Passed`.
- `run_cpu_mem_timing.do`: `Passed`.
- `run_cpu_mem_timing_aggregate.do`: `Passed`.
- `run_cpu_mem_timing2_01.do`: `Passed`.
- `run_cpu_mem_timing2_02.do`: `Passed`.
- `run_cpu_mem_timing2_03.do`: `Passed`.
- `run_cpu_mem_timing2.do`: `Passed`.
- `run_cpu_mem_timing2_aggregate.do`: `Passed`.
- `run_timer.do`: `Passed`.
- `run_cpu_smoke.do`: `Passed`.
- `run_cpu_blargg_02.do`: `Passed`.
- `run_bus_controller.do`: `Passed`.
- `run_cpu_video_smoke_top.do`: `Passed`.
- `run_cpu_timer_blargg_probe.do`: diagnostic completed, matching the real ROM
  for the first measured opcode family.

The ROM runner now supports both Blargg link-port serial output and the
cartridge-RAM status protocol used by `mem_timing-2` at `0xA000`.
`interrupt_time.gb` reaches `Passed`, confirming the current interrupt-entry
path matches Blargg's 13-cycle expectation. `halt_bug.gb` also reaches `Passed`
with the current core. That closes the local Blargg CPU/timing ladder available
in this repository; the next meaningful project step is to checkpoint this phase
and begin the first real PPU slice, while local probes remain strictly debugging
aids.
