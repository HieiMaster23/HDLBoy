# Game Boy DMG — FPGA Hardware Reimplementation

## Project Identity

- **Project name:** gameboy-fpga-core
- **Author:** Rafael Siqueira de Oliveira
- **Objective:** Hardware reimplementation (NOT software emulation) of the Nintendo Game Boy DMG-01 in synthesizable VHDL
- **Purpose:** Professional portfolio project targeting FPGA Design Engineer positions at international companies
- **Language:** All code, comments, commit messages, and documentation in **English**
- **Status:** Starting from M0 (infrastructure setup)

---

## Target Hardware Platform

### FPGA Board: OMDAZZ RZ-EasyFPGA A2.2

- **FPGA:** Altera Cyclone IV EP4CE6 E22C8N
  - 6,272 Logic Elements
  - 276,480 bits of Block RAM (30× M9K blocks ≈ 33.6 KB)
  - 15 embedded 18×18-bit multipliers
  - 2 PLLs
  - Package: EQFP-144 (E22C8N)
- **Clock:** 50 MHz active crystal oscillator
- **External SDRAM:** 64 Mbit (8 MB) — for cartridge ROM storage
- **SPI Flash:** M25P16 (16 Mbit / 2 MB) — persistent storage
- **EEPROM:** AT24C08 (8 Kbit / 1 KB) — save data (optional)
- **Video output:** VGA connector (accent DAC via resistor network)
- **Input:** 4 push-button keys + 4 DIP switches + PS/2 keyboard connector
- **Audio:** Buzzer (PWM only; real audio requires external R-2R DAC on GPIO)
- **Debug:** 4 LEDs, LCD 1602/12864, RS-232 serial (SP3232), JTAG
- **Other:** Infrared receiver, I/O expansion pins (active crystal GPIO headers)

### EDA Toolchain

- **Synthesis & P&R:** Quartus II 13.0 SP1 (last version supporting Cyclone IV)
- **Simulation:** ModelSim-Altera (bundled with Quartus 13.0 SP1)
- **Programming:** USB-Blaster via JTAG
- **Constraint format:** `.qsf` for pin assignments, `.sdc` for timing constraints

### Resource Budget

Total available: 6,272 LEs / 33.6 KB block RAM / 2 PLLs / 15 multipliers.
Estimated usage for complete Game Boy core (without APU): 4,250–6,300 LEs / ~22 KB block RAM / 2 PLLs / 0 multipliers.
This is a tight-resource project — optimization matters and should be documented.

---

## Game Boy DMG-01 Hardware Reference

The original Game Boy hardware to be reimplemented:

### CPU — Sharp LR35902
- 8-bit processor, Z80-like with custom modifications (no IX/IY, no shadow registers, different flag behavior on some instructions)
- Clock: 4.194304 MHz (derived from 50 MHz via PLL)
- Registers: A, F (flags: Z, N, H, C), B, C, D, E, H, L, SP (16-bit), PC (16-bit)
- Register pairs: AF, BC, DE, HL (HL also used as memory pointer)
- Instruction set: 256 base opcodes + 256 CB-prefixed opcodes (bit operations)
- 4 T-states per M-cycle (1 M-cycle = 1 memory access @ 1.048576 MHz)
- Interrupts: VBlank, STAT, Timer, Serial, Joypad (priority order)
- Interrupt mechanism: IME flag, IE register (0xFFFF), IF register (0xFF0F)

### PPU — Pixel Processing Unit
- Resolution: 160×144 pixels, 4 shades of gray (2-bit per pixel)
- Tile-based: 8×8 pixel tiles, 32×32 tile map (256×256 virtual background)
- Layers: Background, Window (overlay), Sprites (OAM: up to 40, max 10 per scanline)
- Rendering modes per scanline: Mode 2 (OAM scan, 80 dots) → Mode 3 (pixel transfer, 168–291 dots) → Mode 0 (HBlank)
- VBlank: Mode 1, 10 scanlines (lines 144–153)
- Key registers: LCDC, STAT, SCY, SCX, LY, LYC, WY, WX, BGP, OBP0, OBP1
- DMA: OAM DMA transfer (0xFF46), 160 bytes in 160 M-cycles

### Memory Map
```
0x0000–0x3FFF  ROM Bank 0 (16 KB, fixed)
0x4000–0x7FFF  ROM Bank 1–N (16 KB, switchable via MBC)
0x8000–0x9FFF  VRAM (8 KB)
0xA000–0xBFFF  External RAM (cartridge, 8 KB switchable)
0xC000–0xDFFF  Work RAM (8 KB)
0xE000–0xFDFF  Echo RAM (mirror of 0xC000–0xDDFF, not used)
0xFE00–0xFE9F  OAM (160 bytes, sprite attribute table)
0xFEA0–0xFEFF  Unusable
0xFF00–0xFF7F  I/O Registers
0xFF80–0xFFFE  HRAM (127 bytes, high RAM)
0xFFFF         IE Register (interrupt enable)
```

### Timer
- DIV (0xFF04): Increments at 16384 Hz (read/write resets to 0)
- TIMA (0xFF05): Timer counter, increments at rate set by TAC
- TMA (0xFF06): Timer modulo (value loaded on TIMA overflow)
- TAC (0xFF07): Timer control (enable + clock select: 4096/262144/65536/16384 Hz)
- Overflow triggers Timer interrupt

### Joypad (0xFF00)
- Active-low button matrix, selected by writing to bits 4–5
- Bit 5 = 0: Select action buttons (A, B, Select, Start)
- Bit 4 = 0: Select direction buttons (Right, Left, Up, Down)
- Bits 0–3: Button state (0 = pressed)

### APU — Audio Processing Unit (optional milestone)
- Channel 1: Pulse with sweep (frequency sweep, envelope, duty cycle)
- Channel 2: Pulse without sweep (envelope, duty cycle)
- Channel 3: Wave (custom 4-bit wave pattern, 32 samples)
- Channel 4: Noise (LFSR-based, envelope)
- Master volume and channel panning (left/right)

---

## Project Architecture

### Module Hierarchy

```
gameboy_top.vhd                 — Top-level: clock generation, module instantiation, pin mapping
├── pll_core.vhd                — PLL wrapper: 50 MHz → 4.194304 MHz (CPU) + 25.175 MHz (VGA)
├── cpu.vhd                     — Sharp LR35902 CPU core
│   ├── alu.vhd                 — 8-bit ALU with flag generation
│   ├── registers.vhd           — Register file (A, F, BC, DE, HL, SP, PC)
│   └── decoder.vhd             — Instruction decoder + control FSM
├── bus_controller.vhd          — Address decoding + bus arbitration (CPU vs PPU)
├── ppu.vhd                     — Pixel Processing Unit
│   ├── ppu_fetcher.vhd         — Tile/sprite data fetcher
│   ├── ppu_fifo.vhd            — Background/sprite pixel FIFOs
│   └── ppu_oam_scan.vhd        — OAM sprite scanner
├── framebuffer.vhd             — 160×144×2-bit dual-port RAM (PPU writes, VGA reads)
├── vga_controller.vhd          — VGA 640×480@60Hz timing + 3x upscaling from framebuffer
├── timer.vhd                   — DIV, TIMA, TMA, TAC + interrupt generation
├── joypad.vhd                  — Joypad register + input debouncing
├── sdram_controller.vhd        — SDRAM interface (init, refresh, read/write)
├── rom_loader.vhd              — UART-based ROM loading into SDRAM
├── memory.vhd                  — Internal memories (WRAM 8KB, HRAM 127B, boot ROM)
├── interrupt_controller.vhd    — IE, IF registers + interrupt dispatch logic
├── apu.vhd (optional)          — Audio Processing Unit (4 channels)
└── ps2_controller.vhd (opt.)   — PS/2 keyboard decoder for joypad input
```

### Clock Domains

- **clk_cpu** (4.194304 MHz): CPU, bus controller, timer, joypad, memory, PPU logic
- **clk_vga** (25.175 MHz): VGA timing, framebuffer read port
- **clk_sdram** (100–133 MHz, optional): SDRAM controller (if needed for bandwidth; otherwise clk_cpu may suffice with wait states)

Clock domain crossings between clk_cpu and clk_vga occur at the framebuffer (dual-port RAM handles this naturally) and must be properly synchronized for any status/control signals.

### VGA Output Mapping

- Game Boy native: 160×144, 2-bit (4 shades)
- VGA output: 640×480 @ 60Hz
- Upscaling: 3× integer scale → 480×432 display area, centered with black borders
- Pixel clock: 25.175 MHz (generated by PLL from 50 MHz)
- Palette: 2-bit GB value → RGB mapping (e.g., 0b00 → white, 0b11 → near-black)

### Input Mapping (Initial — Buttons + DIP Switches)

```
DIP Switch 1 → D-Pad Right
DIP Switch 2 → D-Pad Left
DIP Switch 3 → D-Pad Up
DIP Switch 4 → D-Pad Down
Key 1        → A Button
Key 2        → B Button
Key 3        → Select
Key 4        → Start
```

### Input Mapping (Final — PS/2 Keyboard)

```
W → Up,  A → Left,  S → Down,  D → Right
J → A,   K → B
Enter → Start,  Space → Select
```

---

## Development Milestones

### M0 — Infrastructure & Environment Setup (Weeks 1–2)
Setup Quartus project, directory structure, Git repo, pin assignments (.qsf), timing constraints (.sdc), blink LED test on hardware. README with project description and architecture.

### M1 — VGA Controller 640×480@60Hz (Weeks 3–5)
VGA timing module (hsync, vsync, pixel coordinates, blanking). PLL for 25.175 MHz. Test with static color bar pattern on monitor. Automated testbench for timing verification.

### M2 — Framebuffer & Pixel Pipeline (Weeks 5–7)
Dual-port block RAM framebuffer (160×144×2-bit). 3× upscaling logic for VGA. Palette mapping. Demo: static image displayed via VGA.

### M3 — CPU Core — Sharp LR35902 (Weeks 8–14) ⭐ CRITICAL
Full CPU implementation: registers, ALU (flags Z/N/H/C, half-carry, DAA), instruction decoder (all 512 opcodes), cycle-accurate M-cycle timing, interrupt handling. Incremental approach: start with LD/ADD/SUB/JR/JP/CALL/RET/PUSH/POP, expand to full set. Validate with Blargg's cpu_instrs test ROMs.

### M4 — Memory Map & Bus Controller (Weeks 14–16)
Address decoding for full Game Boy memory map. CPU/PPU bus arbitration for VRAM and OAM. I/O register routing.

### M5 — PPU — Pixel Processing Unit (Weeks 17–22) ⭐ CRITICAL
Background rendering (tile map + tile data + scrolling). Window layer. Sprite rendering (OAM scan, priority, 10-per-line limit). PPU modes with correct timing. VBlank/STAT interrupts. Integration with framebuffer. Validate with dmg-acid2 test ROM.

### M6 — Timer, Joypad & I/O (Weeks 22–24)
Timer (DIV/TIMA/TMA/TAC) with overflow interrupt. Joypad register with multiplexed button reading. Input via physical buttons + DIP switches. Validate with Blargg's timer tests.

### M7 — SDRAM Controller & ROM Loading (Weeks 24–27)
SDRAM init/refresh/read/write with correct timing. UART ROM loader (PC → SDRAM). MBC1 mapper for bank-switched ROMs (>32 KB).

### M8 — Final Integration & Boot ROM (Weeks 27–30) 🎯 FIRST PLAYABLE
All subsystems integrated in top-level. Custom boot ROM (avoid Nintendo IP). Resource optimization if needed. Target: Tetris or homebrew ROM running on hardware.

### M9 — APU (Optional, Weeks 30–34)
4 audio channels. Output via PWM or external R-2R DAC on GPIO.

### M10 — PS/2 Keyboard (Optional, Weeks 34–35)
PS/2 protocol decoder. Key-to-button mapping. Integration with joypad module.

---

## Coding Conventions

### VHDL Style

- **Standard:** VHDL-1993 (compatible with Quartus 13.0 SP1)
- **Libraries:** Use ONLY `ieee.std_logic_1164` and `ieee.numeric_std`. NEVER use `ieee.std_logic_arith` or `ieee.std_logic_unsigned` — these are non-standard Synopsys packages.
- **Naming:**
  - Signals: `snake_case` (e.g., `pixel_data`, `cpu_addr`)
  - Constants: `UPPER_SNAKE_CASE` (e.g., `SCREEN_WIDTH`, `CPU_FREQ`)
  - Entities: `snake_case` matching filename (e.g., entity `vga_controller` in `vga_controller.vhd`)
  - Generics: `UPPER_SNAKE_CASE` with `G_` prefix (e.g., `G_ADDR_WIDTH`)
  - Ports: `snake_case` with directional suffix where helpful (e.g., `data_in`, `data_out`)
  - Clock signals: `clk` or `clk_<domain>` (e.g., `clk_cpu`, `clk_vga`)
  - Reset: `reset_n` (active-low, directly from board RESET button) or `reset` (active-high internal)
  - Active-low signals: `_n` suffix (e.g., `cs_n`, `we_n`, `oe_n`)
  - Registered outputs: no special suffix, but document in header
- **Reset strategy:** Synchronous reset preferred for Altera (uses dedicated logic). Asynchronous reset from board button synchronized with 2-FF synchronizer at top level.
- **Clock:** All sequential logic in `rising_edge(clk)` processes. No `falling_edge` unless required by external interface (e.g., SDRAM).
- **Processes:** Use named processes with descriptive labels (e.g., `p_instruction_decode: process(clk_cpu)`).
- **Comments:** Every module header must include: description, author, date, port descriptions. Inline comments for non-obvious logic. Explain WHY, not WHAT.
- **File header template:**

```vhdl
-- =============================================================================
-- Module:      <module_name>
-- Description: <one-line description>
-- Author:      Rafael Siqueira de Oliveira
-- Created:     <date>
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- <date> - <description of change>
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
```

### Testbench Style

- Filename: `tb_<module_name>.vhd` (e.g., `tb_vga_controller.vhd`)
- Self-checking where possible (assert statements with severity failure)
- Clock generation as concurrent process
- Stimulus as sequential process with clear phases
- Use `report` statements for test progress visibility
- End simulation with `std.env.stop` or `wait` after all tests complete

### Synthesis Guidelines

- Avoid latches: every `if` in a combinational process must have an `else`; every `case` must have `when others`
- Register all outputs crossing module boundaries
- Use synchronous reset (Altera recommended)
- Infer block RAM with appropriate templates (dual-port for framebuffer/VRAM)
- Avoid initial values on signals for synthesis (use reset instead)
- Target Fmax: comfortably above 4.194 MHz for CPU domain, above 25.175 MHz for VGA domain

---

## Repository Structure

```
gameboy-fpga-core/
├── rtl/                        — Synthesizable VHDL source
│   ├── cpu/                    — CPU core (cpu.vhd, alu.vhd, registers.vhd, decoder.vhd)
│   ├── ppu/                    — PPU (ppu.vhd, ppu_fetcher.vhd, ppu_fifo.vhd, ppu_oam_scan.vhd)
│   ├── memory/                 — Memory modules (memory.vhd, sdram_controller.vhd, framebuffer.vhd)
│   ├── video/                  — VGA controller (vga_controller.vhd)
│   ├── io/                     — I/O modules (timer.vhd, joypad.vhd, ps2_controller.vhd)
│   ├── audio/                  — APU (apu.vhd) — optional
│   ├── top/                    — Top-level (gameboy_top.vhd, pll_core.vhd)
│   └── common/                 — Shared packages (gb_types_pkg.vhd — constants, types, subtypes)
├── tb/                         — Testbenches
│   ├── cpu/
│   ├── ppu/
│   ├── memory/
│   ├── video/
│   ├── io/
│   └── integration/            — System-level testbenches
├── constraints/                — Quartus constraint files
│   ├── pin_assignments.qsf     — OMDAZZ board pin assignments
│   └── timing.sdc              — Timing constraints (clock definitions, false paths)
├── quartus/                    — Quartus project files
│   ├── gameboy_core.qpf        — Project file
│   └── gameboy_core.qsf        — Settings file (includes constraints/pin_assignments.qsf)
├── scripts/                    — Build and utility scripts
│   ├── build.tcl               — Quartus Tcl build script (compile + fit + assemble)
│   ├── program.tcl             — Quartus Tcl programming script
│   └── rom_loader.py           — Python UART ROM loader utility
├── docs/                       — Documentation
│   ├── architecture.md         — System architecture and block diagrams
│   ├── resource_utilization.md — Post-synthesis resource reports per milestone
│   └── design_decisions.md     — Key trade-offs and design rationale
├── sim/                        — Simulation scripts and wave configs
│   └── modelsim/               — ModelSim .do scripts
├── .gitignore
├── LICENSE                     — MIT License (recommended for portfolio)
└── README.md                   — Project overview, build instructions, status (English)
```

---

## Git Workflow

- **Commit messages:** English, imperative mood, descriptive (e.g., "Add VGA hsync/vsync timing generation", not "updated vga")
- **Tags:** `vM.X` for each milestone completion (e.g., `v0.0` for M0, `v0.1` for M1, ..., `v1.0` for M8 first playable)
- **Branches:** `main` for stable milestones, `dev/<milestone>` for work-in-progress (e.g., `dev/m1-vga`)
- **.gitignore** must exclude: `db/`, `incremental_db/`, `output_files/`, `simulation/`, `*.bak`, `*.qws`, and any generated files. Include only source, constraints, scripts, docs, and project config.

---

## Pin Assignments Reference (OMDAZZ RZ-EasyFPGA A2.2)

> **IMPORTANT:** The exact pin assignments for this board must be verified against the official OMDAZZ schematic or user manual. The assignments below are typical for this board model but MUST be confirmed before hardware testing. When in doubt, trace the schematic or test with a multimeter.

### Clock and Reset
```
set_location_assignment PIN_23 -to clk_50mhz
set_location_assignment PIN_25 -to reset_n
```

### VGA (accent accent — verify accent resistance network and accent pin mapping from schematic)
```
# These are TYPICAL assignments — verify against your specific board revision
set_location_assignment PIN_XXX -to vga_r[0]
set_location_assignment PIN_XXX -to vga_r[1]
set_location_assignment PIN_XXX -to vga_r[2]
set_location_assignment PIN_XXX -to vga_g[0]
set_location_assignment PIN_XXX -to vga_g[1]
set_location_assignment PIN_XXX -to vga_g[2]
set_location_assignment PIN_XXX -to vga_b[0]
set_location_assignment PIN_XXX -to vga_b[1]
set_location_assignment PIN_XXX -to vga_hsync
set_location_assignment PIN_XXX -to vga_vsync
```

### Keys and DIP Switches
```
# Keys (directly accent accent accent accent accent connected, active-low typically)
set_location_assignment PIN_XXX -to key_n[0]
set_location_assignment PIN_XXX -to key_n[1]
set_location_assignment PIN_XXX -to key_n[2]
set_location_assignment PIN_XXX -to key_n[3]

# DIP Switches
set_location_assignment PIN_XXX -to dip_sw[0]
set_location_assignment PIN_XXX -to dip_sw[1]
set_location_assignment PIN_XXX -to dip_sw[2]
set_location_assignment PIN_XXX -to dip_sw[3]
```

### LEDs
```
set_location_assignment PIN_XXX -to led[0]
set_location_assignment PIN_XXX -to led[1]
set_location_assignment PIN_XXX -to led[2]
set_location_assignment PIN_XXX -to led[3]
```

### SDRAM (64 Mbit — verify chip model and pin mapping)
```
# SDRAM signals: clk, cke, cs_n, ras_n, cas_n, we_n, dqm[1:0], ba[1:0], addr[12:0], dq[15:0]
# Pin assignments MUST be extracted from board schematic — too many signals for guesswork
```

### UART (RS-232 via SP3232)
```
set_location_assignment PIN_XXX -to uart_tx
set_location_assignment PIN_XXX -to uart_rx
```

### PS/2
```
set_location_assignment PIN_XXX -to ps2_clk
set_location_assignment PIN_XXX -to ps2_data
```

> **First action for M0:** Locate and download the OMDAZZ RZ-EasyFPGA A2.2 schematic PDF and/or example projects from the seller. Extract all pin assignments from the schematic into `constraints/pin_assignments.qsf`. This is a prerequisite for any hardware testing.

---

## Key Technical References

- **Pan Docs** — https://gbdev.io/pandocs/ — Comprehensive Game Boy technical reference (primary source)
- **Game Boy CPU opcode table** — https://gbdev.io/gb-opcodes/optables/ — Complete opcode reference with flags and timing
- **Blargg's test ROMs** — CPU instruction tests, timer tests, memory timing tests
- **dmg-acid2** — PPU rendering accuracy test ROM
- **SDRAM datasheet** — Obtain for the specific chip on the OMDAZZ board (likely HY57V2562GTR or similar)
- **Altera Cyclone IV Device Handbook** — Block RAM, PLL, I/O standards documentation
- **VGA timing** — 640×480 @ 60Hz: pixel clock 25.175 MHz, hsync 31.47 kHz, vsync 59.94 Hz

---

## Notes for Claude Code

- All code and documentation must be in **English**
- Use **VHDL-1993** — do not use VHDL-2008 features (Quartus 13.0 SP1 has limited support)
- **NEVER** use `ieee.std_logic_arith` or `ieee.std_logic_unsigned` — only `ieee.numeric_std`
- When generating pin assignments, always note that they need verification against the board schematic
- When estimating resources, always consider the 6,272 LE budget and flag when approaching 80%+ utilization
- Each module should be independently simulatable with its own testbench
- Prioritize correctness over optimization in early milestones; optimize in M8
- The Game Boy clock (4.194304 MHz) must be cycle-accurate for compatibility — approximate clocks will break games
- This is a portfolio project: code quality, documentation, and commit hygiene matter as much as functionality

---

## Debug Workflow & SignalTap II

### Two-Environment Debug Model

This project uses a split workflow for development and analysis:

- **Claude Code (this tool):** Implementation — writing VHDL, testbenches, build scripts, commits, structural work. Claude Code does NOT see simulation waveforms, hardware output, or SignalTap captures.
- **Claude.ai chat (separate conversation):** Analysis and design review — the author brings ModelSim waveform screenshots, SignalTap captures, Quartus timing reports, VGA output photos, and resource utilization reports to the chat for discussion, interpretation, and debugging guidance.

When debugging, the standard procedure is:
1. Simulate in ModelSim first (testbench written here in Claude Code)
2. If simulation passes but hardware fails, use SignalTap to capture real signals
3. Compare simulation waveform vs. SignalTap capture
4. Bring both screenshots to the Claude.ai chat for analysis if the divergence is not obvious

### SignalTap II Integration

SignalTap II is Altera's embedded logic analyzer. It uses block RAM to capture internal FPGA signals in real-time, triggered by user-defined conditions.

**Resource constraints on EP4CE6:**
- SignalTap consumes block RAM for sample storage (M9K blocks)
- Total block RAM budget: ~33.6 KB. Game Boy core estimate: ~22 KB.
- Available for SignalTap: ~11 KB maximum, but less as the project grows
- Practical limit: capture 8–16 signals at 1K–4K sample depth during early milestones (M0–M2)
- In later milestones (M5+), SignalTap may need to be removed entirely to free block RAM
- **Always remove SignalTap from the design before tagging a milestone release**

**SignalTap project conventions:**
- SignalTap configuration files (.stp) go in `debug/signaltap/`
- Do NOT commit .stp files with active captures (large binary data)
- Document any SignalTap-discovered bugs in commit messages: "Fix hsync timing (off-by-one found via SignalTap)"

**Typical SignalTap use cases in this project:**
- M1 (VGA): Verify hsync/vsync timing, pixel clock frequency, blanking intervals
- M2 (Framebuffer): Verify dual-port RAM read/write arbitration
- M3 (CPU): Capture instruction fetch/execute cycle timing (limited signals due to RAM budget)
- M7 (SDRAM): Verify SDRAM init sequence, refresh timing, read/write strobes — this is where SignalTap is most critical, as SDRAM timing bugs are nearly impossible to find without hardware capture

**Industry context:** SignalTap is the Altera/Intel tool. The Xilinx/AMD equivalent is Integrated Logic Analyzer (ILA), instantiated via Vivado. In ASIC flows, similar debug capabilities are achieved with scan chains and DFT (Design for Test) structures. Proficiency with embedded logic analyzers is an expected skill for FPGA Design Engineer roles.

### Timing Analysis Workflow

After each synthesis run, check the Timing Analyzer report in Quartus:
- Verify all clocks meet Fmax requirements: clk_cpu > 4.194 MHz, clk_vga > 25.175 MHz
- Check for unconstrained paths (indicates missing SDC constraints)
- Check for clock domain crossing violations between clk_cpu and clk_vga
- Document Fmax and critical path in `docs/resource_utilization.md` per milestone

If timing fails, bring the Quartus Timing Analyzer screenshot to the Claude.ai chat for analysis before attempting fixes.