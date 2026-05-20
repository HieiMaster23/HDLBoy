# Development Roadmap

This document explains how the project is intended to grow from isolated FPGA
building blocks into a coherent Game Boy DMG-01 hardware reimplementation.

The central rule is that each new subsystem must be added only after the
contracts it depends on are already observable, testable, and affordable on the
Cyclone IV EP4CE6 target.

## Development Principle

The project is not a software emulator. It is a hardware reconstruction, so the
main engineering problem is not only implementing each block, but making the
blocks agree on:

- clocking;
- memory-map behavior;
- interrupt flow;
- timing;
- ownership of shared resources;
- FPGA resource cost.

The project therefore grows by evidence:

1. implement a small hardware slice;
2. test it in simulation;
3. synthesize it when RTL changes;
4. measure resource impact;
5. validate on hardware when the slice has visible behavior;
6. document the new boundary before expanding it.

## Current Position

The project has already completed the early foundation layers:

1. **Board bring-up**
   - clock, reset, LEDs, JTAG, and Quartus flow are working;
   - the real target board has been validated.
2. **Video foundation**
   - VGA timing is working in hardware;
   - the framebuffer and scaling pipeline are working in hardware.
3. **CPU behavior foundation**
   - the LR35902 core is multi-cycle and modular;
   - the individual Blargg `cpu_instrs` ROMs all pass through the serial runner.
4. **System-bus foundation**
   - full WRAM, HRAM, IE/IF, serial debug, and a memory-ready path exist;
   - the bus is now shaped like a real system component instead of a smoke-test
     convenience block.
5. **Initial timer foundation**
   - the duplicated timer stub has been replaced by a reusable DMG-style timer
     block shared by simulation and the bus controller.
6. **First PPU foundation**
   - real VRAM now exists at `0x8000..0x9FFF`;
   - a first background-only renderer reads tile data plus the background tile
     map from VRAM and feeds the framebuffer path.
7. **First CPU/PPU integration**
   - the CPU now writes deterministic tile data and tile-map contents into VRAM;
   - the PPU renders those CPU-authored contents through the VGA path;
   - the complete path has been visually confirmed on the real board.
8. **Explicit visual test-program flow**
   - the bus controller now consumes ROM bytes through a port instead of owning
     embedded demo contents;
   - dedicated ROM modules hold the smoke and CPU/PPU demo programs.
9. **First LCD register behavior**
   - `SCX` and `SCY` now reach the background renderer;
   - the CPU-authored visual program writes scroll values before rendering.
10. **Initial scanline-oriented PPU structure**
    - the background renderer now has explicit visible-line boundaries;
    - `current_line`, `line_active`, and `line_done` make the next LY/STAT
      integration step observable.
11. **Minimal LY/STAT register visibility**
    - `LY` now reflects the PPU scanline signal through the bus;
    - this first slice preserved writable bits, reported `LY=LYC`, and exposed
      the temporary mode field that the next slice replaced.
12. **Initial PPU mode scheduler**
    - the renderer now emits an explicit `ppu_mode` value for `STAT`;
    - the current line-level scheduler reports Mode 2, Mode 3, Mode 0, and
      Mode 1/VBlank deterministically;
    - this replaces the previous active-line placeholder without changing the
      visual output.
13. **Initial VBlank and STAT interrupts**
    - VBlank entry now requests IF bit 0;
    - enabled STAT Mode 0, Mode 1, Mode 2, and `LY=LYC` sources now request
      IF bit 1;
    - requests are edge-detected at the current line-level scheduler boundary.
14. **Initial dot-based PPU scheduler**
    - the renderer now carries a logical 456-dot counter per scanline;
    - visible lines expose Mode 2 at dots `0..79`, Mode 3 at `80..251`, and
      Mode 0 at `252..455`;
    - VBlank lines `144..153` expose Mode 1 across the same dot range;
    - the current visual CPU-authored VRAM path is preserved.
15. **Initial LCDC enable behavior**
    - the bus exports `LCDC(7)` as `ppu_lcd_enable`;
    - CPU-visible `LY/STAT` use line zero and Mode 0 when LCD is disabled;
    - PPU VBlank/STAT requests are masked while LCD is disabled;
    - the background renderer remains inactive while LCD is disabled.
16. **Initial VRAM Mode 3 access blocking**
    - CPU VRAM reads return `0xFF` during Mode 3 while LCD is enabled;
    - CPU VRAM writes are ignored during Mode 3 while LCD is enabled;
    - VRAM remains accessible while LCD is disabled;
    - the CPU-authored background demo remains the visual baseline.
17. **Initial OAM storage and access blocking**
    - CPU OAM is decoded at `0xFE00..0xFE9F`;
    - CPU OAM reads return `0xFF` during Mode 2/3 while LCD is enabled;
    - CPU OAM writes are ignored during Mode 2/3 while LCD is enabled;
    - OAM remains accessible while LCD is disabled;
    - the unusable `0xFEA0..0xFEFF` range remains open-bus high.
18. **Continuous PPU frame loop**
    - after the first start pulse, the background renderer loops continuously
      while LCD is enabled;
    - `done` is now a one-cycle frame-complete pulse;
    - visual tops latch the pulse for stable LED debug indication;
    - LCD disable still holds the renderer inactive at line 0, dot 0.
19. **BGP palette lookup**
    - `bus_controller` exposes the CPU-written `BGP` register to the PPU path;
    - `ppu_background_renderer` maps background color ids through `BGP` before
      writing framebuffer pixels;
    - the default `BGP = 0xFC` keeps the previous visual baseline intact.
20. **Initial LCDC background controls**
    - `bus_controller` exposes the full CPU-written `LCDC` register to the PPU
      path;
    - `LCDC(3)` selects the background tile map base;
    - `LCDC(4)` selects unsigned versus signed tile data addressing;
    - `LCDC(0)` initially forces background color id 0 when background display
      is disabled.
21. **Initial PPU OAM scan**
    - `ppu_oam_scan` reads OAM through a dedicated PPU-side port;
    - the scanner starts at visible-line Mode 2 dot zero;
    - it scans 40 sprite Y bytes over 80 cycles and records up to 10 candidate
      indices for the current line;
    - `LCDC(1)` disables candidate collection and `LCDC(2)` selects 8x8 versus
      8x16 sprite height.
22. **First sprite pixel fetch/composition**
    - the background renderer consumes the first OAM scan candidate;
    - it fetches that sprite's OAM metadata and tile row;
    - nonzero OBJ pixels are overlaid on the background through `OBP0`;
    - `LCDC(1)` preserves the background-only path when sprites are disabled.

The project has completed the local CPU/timing ladder available in the current
Blargg package and has entered the first **real PPU** implementation phase.

## Why the CPU Came Before the Real PPU

The Game Boy PPU depends on several CPU-visible contracts:

- access to VRAM and I/O registers;
- interrupt behavior;
- cycle timing;
- bus ownership;
- later, DMA and scanline-related coordination.

If the real PPU is started while CPU timing is still too approximate, later
visual failures become ambiguous. A bad frame could come from the PPU, the CPU,
the timer, or the bus. Finishing the next timing layer first reduces that
ambiguity and gives the PPU a firmer base.

The current order is therefore intentional:

1. make the CPU broadly correct;
2. make the bus realistic enough to host real memory;
3. make timing progressively more faithful;
4. begin the real PPU after those shared contracts are stronger.

## Major Development Phases

### Phase 1: Infrastructure and Visible Output

Purpose:

- prove the FPGA flow;
- prove the board;
- prove the VGA path;
- establish a visible debug surface.

Main outputs:

- blinking LEDs;
- VGA timing;
- framebuffer image;
- hardware-visible pass/fail indicators.

### Phase 2: CPU Bring-Up

Purpose:

- build the LR35902 as hardware, not as a software interpreter;
- validate register, ALU, control-flow, stack, memory-transfer, CB-prefixed, and
  interrupt behavior incrementally.

Main outputs:

- modular CPU RTL;
- self-checking unit tests;
- ROM runner with serial capture;
- all individual Blargg `cpu_instrs` tests passing.

### Phase 3: Bus and Peripheral Foundations

Purpose:

- replace ad hoc smoke-test wiring with reusable system structure;
- establish the address map the rest of the machine will depend on;
- keep the design affordable on EP4CE6.

Main outputs:

- registered WRAM reads with wait-state support;
- HRAM;
- IF/IE;
- serial debug path;
- initial timer;
- Quartus resource tracking after each slice.

### Phase 4: Timing Fidelity

Purpose:

- turn a behaviorally correct CPU into a CPU that cooperates with the rest of the
  machine at the right time.

Primary validation targets:

- `instr_timing`;
- `mem_timing`;
- `interrupt_time`;
- `halt_bug.gb`.

This phase is now checkpointed for the local Blargg ladder available in the
repository.

### Phase 5: Real PPU

Purpose:

- replace the current direct framebuffer smoke path with a Game Boy-style pixel
  producer.

Recommended order:

1. VRAM storage;
2. tile data and tile map reads;
3. background-only static image;
4. scrolling;
5. window;
6. sprites and OAM scan;
7. PPU modes, VBlank, STAT, and DMA.

The first real visual milestone is now being implemented as a tile-based
background produced by the PPU, not direct CPU pixel writes. The first hardware
checkpoint of that milestone is already complete: the board displays the
expected centered image with alternating white/checkerboard tiles written by the
CPU into VRAM and consumed by the PPU.

### Phase 6: Playable System Integration

Purpose:

- move from validation ROMs to controlled software experiences.

Needed pieces:

- joypad input;
- sufficiently faithful timer and interrupts;
- PPU good enough for homebrew ROMs;
- ROM loading path;
- eventually cartridge mapping for larger software.

Expected software ladder:

1. custom ROMs with serial output;
2. custom ROMs with controlled graphics;
3. homebrew test ROMs;
4. simple commercial games such as `Tetris` and `Dr. Mario`.

### Phase 7: Audio and Deeper Fidelity

Purpose:

- complete the machine after the first playable target exists.

Main outputs:

- APU channels;
- stronger edge-case compatibility;
- broader regression suites;
- optional input and usability refinements.

The APU matters for completeness, but it is not the primary blocker for the
first playable Game Boy target.

## Dependency View

```text
Board bring-up
  -> VGA/framebuffer
  -> CPU behavior
  -> Bus + WRAM + timer + interrupts
  -> CPU timing fidelity
  -> Real PPU
  -> Joypad + ROM loading + playable integration
  -> APU and deeper compatibility
```

Some work can be parallelized later, but the critical path to a first playable
system is:

```text
CPU timing -> timer/interrupt fidelity -> real PPU -> input/ROM flow -> games
```

## Current Near-Term Roadmap

The next recommended sequence is:

1. keep `instr_timing`, `mem_timing`, `mem_timing-2`, `interrupt_time`, and
   `halt_bug.gb` in the regression set;
2. preserve the current background-only PPU demo as the first isolated visual
   baseline;
3. preserve the new CPU-authored VRAM visual top as the first combined-system
   baseline;
4. preserve the first PPU-side OAM scan module as the sprite-selection baseline;
5. preserve the first one-sprite fetch/composition slice as the OBJ pixel
   baseline;
6. expand sprite composition toward OBP1, priority, ordering, and multiple
   candidates per line;
7. import broader timer coverage later if the local Blargg package proves too
   narrow for the next stages.

## Resource Discipline

The EP4CE6 is a tight target. The last CPU/timing checkpoint used:

- 4,283 / 6,272 logic elements;
- 111,616 / 276,480 block-memory bits;
- 14 / 30 M9K blocks.

The first real VRAM slice already raised memory use to:

- 177,152 / 276,480 block-memory bits;
- 22 / 30 M9K blocks.

The current CPU/PPU visual top with scroll, scanline structure, minimal
`LY/STAT` visibility, initial VBlank/STAT interrupt requests, the dot-based
PPU scheduler, initial LCDC enable handling, and initial VRAM Mode 3 access
blocking plus initial OAM storage, continuous frame looping, BGP palette lookup,
initial LCDC background controls, the first PPU OAM scan, and the first sprite
pixel fetch/composition slice uses:

- 4,551 / 6,272 logic elements;
- 179,200 / 276,480 block-memory bits;
- 23 / 30 M9K blocks.

The PPU phase is therefore memory-sensitive before it becomes logic-heavy. New
work should prefer:

- shared CPU states instead of duplicated datapaths;
- inferred RAMs instead of large register arrays;
- small, testable peripheral slices;
- incremental Quartus checkpoints after meaningful RTL growth.

## What Success Looks Like

The project is on the correct path when each new stage leaves behind:

- a clearer hardware boundary;
- a stronger automated test;
- an updated resource measurement;
- less ambiguity for the next subsystem.

That is the standard that keeps a multi-subsystem FPGA console project
manageable all the way from first blink to first game.
