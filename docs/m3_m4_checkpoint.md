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
| `0x8000..0xD9FF` | Experimental framebuffer/VRAM write window |
| `0xFF80` | Debug LED output register |
| `0xFF81` | Debug status/pass-code register |
| HRAM/IE/IF areas | Reserved for the next M4 slice |

The top-level entity now focuses on integration:

- PLL and reset sequencing
- CPU instantiation
- bus controller instantiation
- framebuffer instance
- VGA controller and pixel pipeline
- seven-segment and LED output

## Step 5: Next Implementation Slice

The next slice should turn `bus_controller.vhd` from a smoke-test map into a
more Game Boy-shaped memory map:

1. Add a small HRAM block for `0xFF80..0xFFFE`.
2. Add IE register at `0xFFFF`.
3. Add IF register placeholder at `0xFF0F`.
4. Decide whether the experimental framebuffer window remains directly mapped
   or becomes a VRAM module.
5. Keep each added region covered by a small self-checking test.
