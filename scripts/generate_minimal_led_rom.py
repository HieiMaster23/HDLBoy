#!/usr/bin/env python3
# =============================================================================
# Script:      generate_minimal_led_rom.py
# Description: Generate a minimal no-MBC Game Boy ROM for SDRAM CPU bring-up
# Author:      Rafael Siqueira de Oliveira
# Created:     2026-05-25
# Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
# Tool:        Python 3
# =============================================================================

from pathlib import Path


ROM_SIZE = 32 * 1024
ENTRY_ADDR = 0x0150
DEFAULT_OUTPUT = Path("roms/minimal_led_blink.gb")

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


def build_rom() -> bytearray:
    rom = bytearray([0x00] * ROM_SIZE)

    # The current FPGA CPU reset vector starts at 0x0000. The standard Game Boy
    # cartridge entry point starts at 0x0100 after boot ROM handoff.
    rom[0x0000:0x0003] = jp(ENTRY_ADDR)
    rom[0x0100:0x0103] = jp(ENTRY_ADDR)
    rom[0x0103] = 0x00
    rom[0x0104:0x0134] = NINTENDO_LOGO

    title = b"MINLED"
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

    # Keep this bring-up program intentionally tiny and deterministic. Build the
    # LED value through register-only increments and write checkpoints 1, 3, 7,
    # and F. This isolates sequential ROM execution without depending on an
    # immediate data byte for the A register.
    program = bytes(
        [
            0xF3,              # DI
            0x31, 0xFE, 0xDF,  # LD SP,$DFFE
            0x3C,              # INC A -> $01
            0xE0, 0x80,        # LDH ($80),A
            0x3C, 0x3C,        # INC A x2 -> $03
            0xE0, 0x80,        # LDH ($80),A
            0x3C, 0x3C,        # INC A x4 -> $07
            0x3C, 0x3C,
            0xE0, 0x80,        # LDH ($80),A
            0x3C, 0x3C,        # INC A x8 -> $0F
            0x3C, 0x3C,
            0x3C, 0x3C,
            0x3C, 0x3C,
            0xE0, 0x80,        # LDH ($80),A
            0x18, 0xFE,        # JR $ ; hold final checkpoint
        ]
    )
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
    print(f"Cartridge type: 0x{rom[0x0147]:02X}")
    print(f"ROM size code: 0x{rom[0x0148]:02X}")
    print(f"Header checksum: 0x{rom[0x014D]:02X}")
    print(f"Global checksum: 0x{rom[0x014E]:02X}{rom[0x014F]:02X}")


if __name__ == "__main__":
    main()
