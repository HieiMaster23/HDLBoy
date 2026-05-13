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
- `LD r,r` for register-to-register transfers that do not involve `(HL)`
- `LD A,(HL)`
- `LD (HL),A`
- `LD HL,nn`
- `LD SP,nn`

ALU and flag instructions:

- `INC r`
- `DEC r`
- `ADD A,r`
- `SUB r`
- `AND A,r`
- `OR A,r`
- `XOR A,r`
- `CP r`

Control flow and stack:

- `JP nn`
- `JR e`
- `CALL nn`
- `RET`
- `PUSH BC/DE/HL/AF`
- `POP BC/DE/HL/AF`

Control base:

- `HALT` enters a halt state and exits when an interrupt is pending.
- `DI` clears IME.
- `EI` uses delayed IME enable after the following completed instruction.

## Current Limitations

- CB-prefixed opcodes are decoded as a control class but not executed yet.
- Conditional jumps, calls, returns, and relative branches are not implemented.
- `LD r,(HL)` and `LD (HL),r` are only implemented for the A-register forms.
- ALU operations using `(HL)` as the source are not executed yet.
- `DAA`, `CPL`, `SCF`, `CCF`, rotate/shift, bit, reset, and set instructions are
  still TODO.
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
- `sim/modelsim/run_cpu_all.do`
- `sim/modelsim/run_cpu_integration_top.do`
- `sim/modelsim/run_cpu_video_smoke_top.do`

The smoke program verifies a small instruction sequence covering immediate
loads, HL memory access, ALU flags, unconditional jump, stack transfer,
subroutine call/return, and relative branch looping.

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
- A temporary framebuffer-mapped window starts at `0x8000`.
- Debug I/O registers at `0xFF80` and `0xFF81` drive LEDs and pass/fail status.
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

## Blargg Preparation

To prepare for Blargg CPU test ROMs, the next implementation slices should:

1. Complete all base opcodes in decoder/execute form.
2. Add CB-prefix decode and execution.
3. Add interrupt vector servicing and exact EI/HALT behavior.
4. Connect the CPU to a memory-map/bus-controller test harness.
5. Add ROM-loaded simulation programs that expose serial output at the Game Boy
   I/O registers used by Blargg tests.

## Next Code Step

Extract the temporary ROM, debug I/O registers, framebuffer address decode, and
pass/fail checker from `cpu_video_smoke_top` into a small memory-map module.
That module should become the first M4-facing bus contract while preserving the
hardware-validated top-level behavior.
