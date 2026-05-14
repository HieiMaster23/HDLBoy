# M3 CPU Implementation

This document tracks the first incremental implementation slice of the Sharp
LR35902 CPU core. The current goal is not full Game Boy compatibility yet; it is
a synthesizable, multi-cycle foundation that can grow toward Blargg CPU test ROM
coverage without being rewritten.

## Strategy

The CPU is split into four RTL modules:

- `rtl/cpu/cpu.vhd`: top-level CPU sequencer, memory bus control, PC/SP updates,
  stack sequencing, HALT bookkeeping, and interrupt state placeholders.
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
- `SUB (HL)`
- `AND A,(HL)`
- `OR A,(HL)`
- `XOR A,(HL)`
- `CP (HL)`
- `RLCA`, `RRCA`, `RLA`, `RRA`
- `CPL`, `SCF`, `CCF`
- CB-prefixed register operations for RLC/RRC/RL/RR/SLA/SRA/SWAP/SRL,
  BIT, RES, and SET. CB operations on `(HL)` remain TODO.
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

## Current Limitations

- CB-prefixed `(HL)` operations are not implemented yet.
- `DAA` remains TODO.
- CB-prefixed register operations are implemented, but they still need broader
  Blargg coverage because the long `09-op r,r` run currently exceeds the short
  runner timeout.
- Interrupt servicing does not yet push PC or jump to vectors. The first version
  exposes IME, pending interrupt detection, and HALT wake-up behavior only.
- The memory interface assumes combinational read data and one-cycle write
  strobes. A later bus controller should add wait-state support.

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

DAA remains a dedicated TODO because it depends on the previous arithmetic
operation and flag state; it should not be approximated.

## Tests

Current ModelSim scripts:

- `sim/modelsim/run_cpu_alu.do`
- `sim/modelsim/run_cpu_registers.do`
- `sim/modelsim/run_cpu_decoder.do`
- `sim/modelsim/run_cpu_smoke.do`
- `sim/modelsim/run_cpu_rom_runner.do`
- `sim/modelsim/run_cpu_blargg_09.do`
- `sim/modelsim/run_cpu_all.do`
- `sim/modelsim/run_cpu_integration_top.do`
- `sim/modelsim/run_cpu_video_smoke_top.do`

The smoke program verifies a small instruction sequence covering immediate
loads, HL memory access, ALU flags, unconditional jump, stack transfer,
subroutine call/return, `(HL)` read-modify-write execution, and relative branch
looping.

`tb_cpu_rom_runner` now loads a real 32 KiB Game Boy ROM image with a VHDL
simulation-only binary file reader. The default target is
`gb-test-roms-master/cpu_instrs/individual/06-ld r,r.gb`.

The runner provides a full 64 KiB simulation memory, captures serial output
through the Game Boy `0xFF01`/`0xFF02` convention, stubs basic I/O registers,
and advances `LY`/`DIV` enough for Blargg's shell delay loops to complete
without a PPU. It stops when the serial transcript contains `Passed` or
`Failed`, or on timeout/unsupported opcode. `G_TIMEOUT_CYCLES` can be raised for
long ROMs without changing the default runner behavior.

Current Blargg bring-up result:

- `cpu_instrs/individual/06-ld r,r.gb`: `Passed` via serial transcript.
- `cpu_instrs/individual/04-op r,imm.gb`: `Passed` via serial transcript.
- `cpu_instrs/individual/08-misc instrs.gb`: `Passed` via serial transcript.
- `cpu_instrs/individual/05-op rp.gb`: `Passed` via serial transcript.
- `cpu_instrs/individual/03-op sp,hl.gb`: `Passed` via serial transcript.
- `cpu_instrs/individual/07-jr,jp,call,ret,rst.gb`: `Passed` via serial transcript.
- `cpu_instrs/individual/09-op r,r.gb`: `Passed` via serial transcript using
  `G_TIMEOUT_CYCLES=25000000`.

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

To prepare for Blargg CPU test ROMs, the next implementation slices should:

1. Complete all base opcodes in decoder/execute form.
2. Add CB-prefix decode and execution.
3. Add interrupt vector servicing and exact EI/HALT behavior.
4. Connect the CPU to a memory-map/bus-controller test harness.
5. Replace the embedded ROM runner program with converted external ROM bytes as
   opcode coverage grows.

## Next Code Step

Use the ROM runner to drive the next CPU opcode slices. The immediate priority
is `11-op a,(hl).gb` to implement `(HL)` ALU coverage and `DAA`. The runner
should stay self-checking, with each new ROM-style test emitting a serial
transcript.
