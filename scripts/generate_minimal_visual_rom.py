#!/usr/bin/env python3
# =============================================================================
# Script:      generate_minimal_visual_rom.py
# Description: Generate a minimal no-MBC ROM for SDRAM-to-video bring-up
# Author:      Rafael Siqueira de Oliveira
# Created:     2026-05-27
# Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
# Tool:        Python 3
# =============================================================================

from pathlib import Path


ROM_SIZE = 32 * 1024
ENTRY_ADDR = 0x0150
DEFAULT_OUTPUT = Path("roms/minimal_visual.gb")

NINTENDO_LOGO = bytes(
    [
        0xCE, 0xED, 0x66, 0x66, 0xCC, 0x0D, 0x00, 0x0B,
        0x03, 0x73, 0x00, 0x83, 0x00, 0x0C, 0x00, 0x0D,
        0x00, 0x08, 0x11, 0x1F, 0x88, 0x89, 0x00, 0x0E,
        0xDC, 0xCC, 0x6E, 0xE6, 0xDD, 0xDD, 0xD9, 0x99,
        0xBB, 0xBB, 0x67, 0x63, 0x6E, 0x0E, 0xEC, 0xCC,
        0xDD, 0xDC, 0x99, 0x9F, 0xBB, 0xB9, 0x33, 0x3E,
    ]
)


def jp(address: int) -> bytes:
    return bytes([0xC3, address & 0xFF, (address >> 8) & 0xFF])


def ld_hl(address: int) -> list[int]:
    return [0x21, address & 0xFF, (address >> 8) & 0xFF]


def ld_hl_imm(value: int) -> list[int]:
    return [0x36, value & 0xFF]


def compute_header_checksum(rom: bytearray) -> int:
    checksum = 0
    for value in rom[0x0134:0x014D]:
        checksum = (checksum - value - 1) & 0xFF
    return checksum


def compute_global_checksum(rom: bytearray) -> int:
    checksum = 0
    for index, value in enumerate(rom):
        if index not in (0x014E, 0x014F):
            checksum = (checksum + value) & 0xFFFF
    return checksum


def append_io_write(program: list[int], address: int, value: int) -> None:
    program.extend(ld_hl(address))
    program.extend(ld_hl_imm(value))


def build_program() -> bytes:
    program: list[int] = [
        0xF3,              # DI
        0x31, 0xFE, 0xDF,  # LD SP,$DFFE
    ]

    append_io_write(program, 0xFF40, 0x00)  # LCDC off while VRAM is prepared.

    # Clear tile 0 at 0x8000..0x800F.
    program.extend(
        [
            0x21, 0x00, 0x80,  # LD HL,$8000
            0xAF,              # XOR A
            0x06, 0x10,        # LD B,$10
            0x22,              # LDI (HL),A
            0x05,              # DEC B
            0x20, 0xFC,        # JR NZ,$-4
        ]
    )

    # Tile 1 checkerboard data at 0x8010..0x801F.
    program.extend([0x21, 0x10, 0x80])
    for value in [0xAA, 0x55] * 4:
        program.extend([0x3E, value, 0x22, 0x22])

    # Clear the complete 32x32 background map at 0x9800..0x9BFF.
    program.extend(
        [
            0x21, 0x00, 0x98,  # LD HL,$9800
            0xAF,              # XOR A
            0x06, 0x04,        # LD B,$04
            0x0E, 0x00,        # LD C,$00
            0x22,              # LDI (HL),A
            0x0D,              # DEC C
            0x20, 0xFC,        # JR NZ,$-4
            0x05,              # DEC B
            0x20, 0xF7,        # JR NZ,$-9
        ]
    )

    # Alternating first tile row: tile 1, tile 0, repeated for 20 tiles.
    program.extend(
        [
            0x21, 0x00, 0x98,  # LD HL,$9800
            0x06, 0x0A,        # LD B,$0A
            0x3E, 0x01,        # LD A,$01
            0x22,              # LDI (HL),A
            0xAF,              # XOR A
            0x22,              # LDI (HL),A
            0x05,              # DEC B
            0x20, 0xF8,        # JR NZ,$-8
        ]
    )

    append_io_write(program, 0xFF47, 0xFC)  # BGP default DMG palette.
    append_io_write(program, 0xFF42, 0x01)  # SCY = 1.
    append_io_write(program, 0xFF43, 0x08)  # SCX = 8.
    append_io_write(program, 0xFF40, 0x91)  # LCDC on, BG on, unsigned tile data.
    append_io_write(program, 0xFF80, 0x01)  # Start the current renderer.
    program.extend([0x18, 0xFE])            # JR $.

    return bytes(program)


def build_rom() -> bytearray:
    rom = bytearray([0x00] * ROM_SIZE)

    rom[0x0000:0x0003] = jp(ENTRY_ADDR)
    rom[0x0100:0x0103] = jp(ENTRY_ADDR)
    rom[0x0103] = 0x00
    rom[0x0104:0x0134] = NINTENDO_LOGO

    title = b"MINVISUAL"
    rom[0x0134:0x0134 + len(title)] = title
    rom[0x0143] = 0x00  # DMG-only
    rom[0x0144] = 0x00
    rom[0x0145] = 0x00
    rom[0x0146] = 0x00  # no SGB
    rom[0x0147] = 0x00  # ROM ONLY
    rom[0x0148] = 0x00  # 32 KiB
    rom[0x0149] = 0x00  # no external RAM
    rom[0x014A] = 0x01  # non-Japanese
    rom[0x014B] = 0x00
    rom[0x014C] = 0x00

    program = build_program()
    rom[ENTRY_ADDR:ENTRY_ADDR + len(program)] = program

    rom[0x014D] = compute_header_checksum(rom)
    global_checksum = compute_global_checksum(rom)
    rom[0x014E] = (global_checksum >> 8) & 0xFF
    rom[0x014F] = global_checksum & 0xFF
    return rom


def main() -> None:
    output_path = DEFAULT_OUTPUT
    output_path.parent.mkdir(parents=True, exist_ok=True)
    rom = build_rom()
    output_path.write_bytes(rom)

    print(f"Wrote {output_path}")
    print(f"Size: {len(rom)} bytes")
    print(f"Program bytes: {len(build_program())}")
    print(f"Cartridge type: 0x{rom[0x0147]:02X}")
    print(f"ROM size code: 0x{rom[0x0148]:02X}")
    print(f"Header checksum: 0x{rom[0x014D]:02X}")
    print(f"Global checksum: 0x{rom[0x014E]:02X}{rom[0x014F]:02X}")


if __name__ == "__main__":
    main()
