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
23. **Serialized 10-candidate sprite composition**
    - the renderer now fetches and stores all 10 per-line OAM scan candidates;
    - `OBP0`/`OBP1` selection and BG/OBJ priority are preserved across the full
      candidate set;
    - the visible OBJ pixel selection was moved from a 10-way combinational path
      into a one-candidate-per-cycle composition step;
    - the top returned from 5,286 logic elements (84%) to 5,013 logic elements
      (80%), saving 273 logic elements while preserving the current tests.
24. **VGA raster scaler optimization**
    - `vga_pixel_pipeline` no longer infers reciprocal-multiply logic for
      divide-by-3 scaling;
    - fixed 3x scaling is tracked with small raster phases and a registered line
      base;
    - the VGA pipeline hierarchy dropped from 141 to 117 logic cells;
    - the top dropped from 5,013 to 4,995 logic elements, though Quartus still
      rounds utilization to 80%.
25. **HRAM M9K inference optimization**
    - HRAM has been moved into a dedicated synchronous single-port memory
      module;
    - Quartus now infers it as one M9K block instead of retaining it as
      distributed registers inside the bus controller;
    - the bus controller hierarchy dropped from 1,870 logic cells / 1,210
      registers to 543 logic cells / 186 registers;
    - the full top dropped from 4,995 to 3,674 logic elements, restoring
      substantial logic margin for the first-playable feature path.
26. **Initial OAM DMA**
    - writes to `0xFF46` now start a 160-byte OAM DMA transfer;
    - this first slice supports WRAM/Echo source pages, covering the
      shadow-OAM-to-OAM path needed by simple games;
    - `cpu_ready` is held low while the transfer is active;
    - no new M9K blocks were added, and the top now uses 3,741 logic elements.

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
first playable Game Boy target. It is explicitly deferred until the CPU, bus,
PPU, input, ROM loading, and first playable integration are functional.

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
6. preserve the first OBP1/BG-priority/two-candidate sprite composition slice as
   the initial multi-OBJ baseline;
7. preserve the full 10-candidate sprite composition slice as the first complete
   per-line OBJ candidate baseline;
8. preserve the serialized sprite composition optimization as the current
   resource baseline;
9. preserve the VGA raster scaler optimization as the current video-output
   resource baseline;
10. preserve configurable bus/debug feature gates so smoke-only logic is
    explicit and opt-in for future tops;
11. preserve the HRAM M9K inference optimization as the current bus-resource
    baseline;
12. preserve the first WRAM/Echo-backed OAM DMA slice as the initial sprite-data
    transfer baseline;
13. preserve the initial real JOYP register slice as the current input baseline;
14. preserve the initial Window rendering slice as the current BG/Window visual
    baseline;
15. preserve the DMG sprite priority refinement as the current OBJ composition
    baseline;
16. preserve the compact PS/2 keyboard joypad mapper as the first physical
    direction-input baseline;
17. preserve the isolated SDRAM controller simulation slice as the first M7
    storage baseline;
18. preserve the dedicated SDRAM hardware bring-up top as the first physical
    external-memory baseline;
19. preserve the byte-stream SDRAM ROM loader core as the transport-independent
    loading baseline before adding the physical Virtual JTAG wrapper;
20. preserve the Virtual JTAG SDRAM loader top as the first USB-Blaster ROM
    loading hardware baseline;
21. preserve the host-side Quartus STP ROM loader script as the first practical
    PC-to-SDRAM transfer path before wiring SDRAM reads into the CPU bus;
22. preserve the SDRAM ROM reader and bus `rom_ready` contract as the first
    read-side cartridge baseline for 32 KiB no-MBC ROMs;
23. preserve the dedicated SDRAM CPU ROM execution top as the first
    load-then-execute baseline before merging SDRAM cartridge fetches into the
    visual CPU/PPU top;
24. preserve `sdram_video_rom_top` as the first compiled load-then-execute
    cartridge/video integration top before attempting a real no-MBC game ROM;
25. import broader timer coverage later if the local Blargg package proves too
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
initial LCDC background controls, the first PPU OAM scan, the first sprite
pixel fetch/composition slice, and the OBP1/BG-priority/two-candidate sprite
composition slice, expanded to all 10 per-line OBJ candidates and then
serialized to reduce the sprite selection path, plus the VGA raster scaler
optimization, configurable bus/debug feature gates, HRAM M9K inference, and the
first WRAM/Echo-backed OAM DMA slice, plus the initial real JOYP register slice,
initial Window rendering, DMG sprite priority refinement, and the compact PS/2
keyboard joypad mapper, uses:

- 3,887 / 6,272 logic elements;
- 180,224 / 276,480 block-memory bits;
- 24 / 30 M9K blocks.

The PPU phase is still memory-sensitive, but logic margin is now much healthier.
The serialized sprite composition step and VGA scaler optimization brought the
design below 5,000 logic elements, and the HRAM M9K inference step then removed
1,321 retained logic elements by replacing a register-heavy HRAM implementation
with one inferred M9K block. The project now has enough logic room to continue
the first-playable path. The first OAM DMA slice then added a gameplay-relevant
transfer path for 67 logic elements and no new M9K blocks. The initial JOYP
slice then added the CPU-visible `0xFF00` input path and Joypad interrupt
request with unchanged memory usage and only four additional registers in the
fitted top. The initial Window slice added the `WY/WX` path and LCDC-controlled
Window tile-map selection for 70 additional logic elements and no extra memory.
The DMG sprite priority refinement then added a serial selected-OBJ accumulator
for 22 logic elements and 12 registers, preserving the 10-candidate limit. The
compact PS/2 joypad mapper then added the first full physical direction-input
path for 56 additional logic elements and 27 registers, with unchanged memory
usage. The design still needs strict discipline because only six M9K blocks
remain free.
New work should
prefer:

- shared CPU states instead of duplicated datapaths;
- inferred RAMs instead of large register arrays;
- small, testable peripheral slices;
- incremental Quartus checkpoints after meaningful RTL growth.

The first SDRAM controller slice is intentionally isolated from the top-level
Game Boy integration. It establishes init, refresh, single-word read, and
single-word write behavior in simulation before the project adds a JTAG ROM
loader. A dedicated `sdram_test_top` now exposes the physical SDRAM pins only
for bring-up, runs a deterministic write/read checker, and restores the main
Quartus QSF after its dedicated build. That keeps the storage path testable
without destabilizing the current CPU/PPU visual baseline.

The first ROM-loading slice is also transport-independent. `sdram_rom_loader`
accepts a byte stream, packs bytes into little-endian 16-bit SDRAM words, and
uses the existing `cmd_accept`/`ready` SDRAM command handshake. The next step is
to connect that stream interface to a small Virtual JTAG wrapper rather than
mixing JTAG protocol parsing with SDRAM command sequencing.

The first Virtual JTAG wrapper is now present as a dedicated loader top rather
than part of the Game Boy top. `virtual_jtag_rom_stream_core` owns the JTAG
data/control/status protocol and the `altera_reserved_tck` to `clk_50mhz`
crossing; `virtual_jtag_rom_stream` is only the Altera `sld_virtual_jtag`
binding. This preserves a clean test boundary and keeps the main CPU/PPU visual
baseline unchanged until a host-side loader script and cartridge mapper are
ready.

The matching host-side script is now `scripts/load_rom_virtual_jtag.tcl`. It is
intentionally conservative: it polls STATUS before each byte and only shifts a
new DATA byte when the hardware reports `stream_ready = 1`, no pending byte, no
loader error, and no protocol overflow. That keeps the first board test easy to
debug. Throughput can be improved later by batching scans only after the basic
USB-Blaster-to-SDRAM transfer is proven on hardware.

The first read-side ROM slice is `sdram_rom_reader`. It maps CPU byte addresses
`0x0000..0x7FFF` to 16-bit SDRAM word addresses, selects the low or high byte,
and exposes a `rom_ready` wait-state signal to the existing bus. Existing
embedded-ROM tops keep `rom_ready = '1'`, so their behavior and fitted resource
use remain unchanged while the SDRAM cartridge path is prepared in isolation.

The first combined SDRAM execution slice is now `sdram_cpu_rom_top`. It keeps
the loader, SDRAM controller, ROM reader, CPU, and bus in one slow CPU-domain
bring-up top, holds the CPU in reset until a Virtual JTAG load completes, and
then lets ROM fetches come from SDRAM through the existing `rom_ready`
contract. This is intentionally separate from the VGA/PPU top so the project
can prove PC-to-SDRAM-to-CPU execution before spending resources on the final
playable integration top.

The first SDRAM/video integration slice is now `sdram_video_rom_top`. It adds
the existing PPU background/sprite renderer, framebuffer, VGA pipeline, and PS/2
joypad path to the load-then-execute SDRAM cartridge flow. The dedicated Quartus
build closes at 4,372 logic elements, 180,224 memory bits, and 24 M9Ks. This is
the right bridge toward a first playable no-MBC ROM, but hardware validation
still needs a minimal visual ROM that initializes VRAM and PPU registers before
starting the renderer.

The minimal visual ROM now exists as `roms/minimal_visual.gb`. It is generated
by `scripts/generate_minimal_visual_rom.py`, writes deterministic tile data,
background map contents, scroll and palette registers, re-enables LCDC, and
then writes the current renderer start marker at `0xFF80`. The next project
step is physical validation through `sdram_video_rom_top`; if that succeeds,
the SDRAM cartridge path has reached the same visual proof point as the earlier
embedded ROM demo.

The APU is intentionally outside the near-term resource budget. It should be
reconsidered only after the non-audio first playable system is working.

## What Success Looks Like

The project is on the correct path when each new stage leaves behind:

- a clearer hardware boundary;
- a stronger automated test;
- an updated resource measurement;
- less ambiguity for the next subsystem.

That is the standard that keeps a multi-subsystem FPGA console project
manageable all the way from first blink to first game.
