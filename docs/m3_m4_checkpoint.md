# M3/M4 Checkpoint Process

This document records the handoff from the validated M3 CPU smoke tests toward
the first M4 memory-map structure.

## Checkpoint Goals

1. Preserve the hardware-validated `cpu_video_smoke_top` behavior.
2. Move temporary ROM, debug I/O, framebuffer decode, and pass/fail checking out
   of the top-level entity.
3. Add self-checking simulation for the exact CPU framebuffer write sequence.
4. Keep SignalTap files out of the main Quartus project flow.
5. Document the next memory-map boundary clearly before expanding the design.

## Step 1: Functional Checkpoint

The current hardware checkpoint is:

- Top-level entity: `cpu_video_smoke_top`
- Hardware result: confirmed functional on the OMDAZZ RZ-EasyFPGA A2.2 board
- Video path: active VGA output through an active VGA-HDMI converter
- CPU result: the ROM program writes a small visible pattern to the framebuffer
- Pass indication: seven-segment display shows `1234`
- Current programmed SOF checksum after bus extraction: `0x00169AF4`

## Step 2: SignalTap Organization

Temporary `.stp` files were moved out of `quartus/` and into the local debug
area:

```text
debug/signaltap/local/
```

That folder is ignored by Git. Probe documentation remains in Markdown under
`docs/`, so useful debug knowledge is preserved without keeping active capture
files in the main source flow.

## Step 3: Simulation Regression

The CPU video regression now runs two self-checking testbenches:

- `tb_cpu_video_bus_controller`
  - Instantiates the CPU and the new bus controller.
  - Confirms exactly 64 framebuffer writes.
  - Checks every expected framebuffer address.
  - Checks black pixel data value `3`.
  - Confirms pass status and display value `1234`.

- `tb_cpu_video_smoke_top`
  - Instantiates the full top-level path.
  - Confirms final LED checkpoint.
  - Confirms the seven-segment display scans `1234`.
  - Confirms active black and white VGA output.

Run both with:

```text
vsim -c -do run_cpu_video_smoke_top.do
```

## Step 4: Initial Bus Controller

The new module is:

```text
rtl/memory/bus_controller.vhd
```

It owns the first temporary CPU-facing memory map:

| Address range | Current behavior |
| --- | --- |
| `0x0000..0x0118` | Internal smoke-test ROM bytes |
| Other ROM addresses | Return `0x00` |
| `0x8000..0xBFFF` | Experimental framebuffer/VRAM write window |
| `0xC000..0xC03F` | Initial 64-byte WRAM page, kept small for EP4CE6 resource control |
| `0xE000..0xE03F` | Echo mirror for the initial WRAM page |
| `0xFF00` | JOYP stub: select bits are writable, buttons read unpressed |
| `0xFF01..0xFF02` | Serial SB/SC stubs |
| `0xFF04..0xFF07` | Timer register stubs; DIV has simple free-running/reset behavior |
| `0xFF40..0xFF4B` | LCD/PPU register stubs for future PPU integration |
| `0xFF80` | Debug LED output register |
| `0xFF81` | Debug status/pass-code register |
| `0xFF80..0xFFFE` | HRAM, with `0xFF80/0xFF81` temporarily overlaid by debug registers |
| `0xFF0F` | IF register placeholder, lower five interrupt request bits |
| `0xFFFF` | IE register, lower five interrupt enable bits feed the CPU |

The top-level entity now focuses on integration:

- PLL and reset sequencing
- CPU instantiation
- bus controller instantiation
- framebuffer instance
- VGA controller and pixel pipeline
- seven-segment and LED output

## Step 5: Next Implementation Slice

The next slice should turn the resource-limited memory map into a scalable
Game Boy-shaped bus:

1. Add a memory-ready/wait-state path to the CPU bus so RAM can use registered
   or block-RAM-backed reads.
2. Move WRAM and HRAM to lower-resource memory structures before expanding
   them to full DMG size.
3. Decide whether the experimental framebuffer window remains directly mapped
   or becomes a VRAM module owned by the PPU path.
4. Replace the temporary smoke-test ROM with a cleaner ROM image flow.
5. Grow I/O stubs into real timer, joypad, interrupt, serial, and PPU modules.
6. Keep each added region covered by a small self-checking test and track
   Quartus resource use after each slice.
