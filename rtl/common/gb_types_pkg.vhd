-- =============================================================================
-- Module:      gb_types_pkg
-- Description: Shared constants, types, and subtypes for Game Boy FPGA core
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-03-18
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-03-18 - Initial creation with clock and display constants
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package gb_types_pkg is

    -- =========================================================================
    -- Clock frequencies
    -- =========================================================================
    constant BOARD_CLK_HZ  : integer := 50_000_000;   -- 50 MHz board oscillator
    constant CPU_CLK_HZ    : integer := 4_194_304;     -- Game Boy CPU clock
    constant VGA_CLK_HZ    : integer := 25_175_000;    -- VGA 640x480 pixel clock

    -- =========================================================================
    -- Game Boy display
    -- =========================================================================
    constant GB_SCREEN_W   : integer := 160;
    constant GB_SCREEN_H   : integer := 144;
    constant GB_COLOR_BITS : integer := 2;             -- 4 shades of gray

    -- =========================================================================
    -- VGA 640x480 @ 60 Hz timing
    -- =========================================================================
    constant VGA_H_VISIBLE : integer := 640;
    constant VGA_H_FRONT   : integer := 16;
    constant VGA_H_SYNC    : integer := 96;
    constant VGA_H_BACK    : integer := 48;
    constant VGA_H_TOTAL   : integer := 800;

    constant VGA_V_VISIBLE : integer := 480;
    constant VGA_V_FRONT   : integer := 10;
    constant VGA_V_SYNC    : integer := 2;
    constant VGA_V_BACK    : integer := 33;
    constant VGA_V_TOTAL   : integer := 525;

    -- =========================================================================
    -- Upscaling (3x integer scale)
    -- =========================================================================
    constant SCALE_FACTOR  : integer := 3;
    constant SCALED_W      : integer := GB_SCREEN_W * SCALE_FACTOR;  -- 480
    constant SCALED_H      : integer := GB_SCREEN_H * SCALE_FACTOR;  -- 432

    -- Centering offsets within 640x480
    constant H_OFFSET      : integer := (VGA_H_VISIBLE - SCALED_W) / 2;  -- 80
    constant V_OFFSET      : integer := (VGA_V_VISIBLE - SCALED_H) / 2;  -- 24

    -- =========================================================================
    -- Memory map boundaries
    -- =========================================================================
    constant ADDR_ROM_START    : unsigned(15 downto 0) := x"0000";
    constant ADDR_ROM_END      : unsigned(15 downto 0) := x"7FFF";
    constant ADDR_VRAM_START   : unsigned(15 downto 0) := x"8000";
    constant ADDR_VRAM_END     : unsigned(15 downto 0) := x"9FFF";
    constant ADDR_EXTRAM_START : unsigned(15 downto 0) := x"A000";
    constant ADDR_EXTRAM_END   : unsigned(15 downto 0) := x"BFFF";
    constant ADDR_WRAM_START   : unsigned(15 downto 0) := x"C000";
    constant ADDR_WRAM_END     : unsigned(15 downto 0) := x"DFFF";
    constant ADDR_OAM_START    : unsigned(15 downto 0) := x"FE00";
    constant ADDR_OAM_END      : unsigned(15 downto 0) := x"FE9F";
    constant ADDR_IO_START     : unsigned(15 downto 0) := x"FF00";
    constant ADDR_IO_END       : unsigned(15 downto 0) := x"FF7F";
    constant ADDR_HRAM_START   : unsigned(15 downto 0) := x"FF80";
    constant ADDR_HRAM_END     : unsigned(15 downto 0) := x"FFFE";
    constant ADDR_IE           : unsigned(15 downto 0) := x"FFFF";

end package gb_types_pkg;
