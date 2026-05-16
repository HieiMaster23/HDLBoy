# CPU Timing Checkpoint

This checkpoint closes the local Blargg CPU/timing ladder currently available in
the repository.

## Checkpoint Commit

- Commit: `acb7991`
- Message: `Checkpoint local CPU timing Blargg suite`

## Preserved Evidence

The checkpoint records passing results for:

- all individual Blargg `cpu_instrs` ROMs;
- `instr_timing.gb`;
- `mem_timing` individual ROMs and aggregate ROM;
- `mem_timing-2` individual ROMs and aggregate ROM;
- `interrupt_time.gb`;
- `halt_bug.gb`.

The regression boundary also keeps the existing local checks in scope:

- CPU smoke and timing probes;
- timer unit test;
- bus-controller regression;
- CPU video smoke integration.

The latest synthesized checkpoint before entering PPU work used:

- `4,283 / 6,272` logic elements;
- `111,616 / 276,480` memory bits;
- `14 / 30` M9K blocks.

## Boundary Meaning

This checkpoint means the project can stop treating the local Blargg CPU/timing
ladder as unfinished bring-up work. Future CPU changes must preserve this suite
as a regression barrier while the architecture begins to grow into the PPU.

It does not mean the CPU is permanently complete. More coverage can still be
added later with broader timer-focused suites, hardware timing captures, or
software that exposes edge cases outside the current local package.

## Next PPU Slice

The next architecture slice should stay intentionally narrow:

1. reserve real VRAM storage;
2. read tile data and tile map bytes from VRAM;
3. produce a background-only pixel stream;
4. write those pixels into the existing framebuffer path;
5. defer sprites, window, STAT, and DMA until the static background path is
   proven.
