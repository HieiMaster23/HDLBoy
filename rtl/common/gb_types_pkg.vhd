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

    -- =========================================================================
    -- CPU register and flag encodings
    -- =========================================================================
    constant CPU_REG_B      : std_logic_vector(2 downto 0) := "000";
    constant CPU_REG_C      : std_logic_vector(2 downto 0) := "001";
    constant CPU_REG_D      : std_logic_vector(2 downto 0) := "010";
    constant CPU_REG_E      : std_logic_vector(2 downto 0) := "011";
    constant CPU_REG_H      : std_logic_vector(2 downto 0) := "100";
    constant CPU_REG_L      : std_logic_vector(2 downto 0) := "101";
    constant CPU_REG_HL_MEM : std_logic_vector(2 downto 0) := "110";
    constant CPU_REG_A      : std_logic_vector(2 downto 0) := "111";

    constant CPU_PAIR_BC    : std_logic_vector(1 downto 0) := "00";
    constant CPU_PAIR_DE    : std_logic_vector(1 downto 0) := "01";
    constant CPU_PAIR_HL    : std_logic_vector(1 downto 0) := "10";
    constant CPU_PAIR_AF    : std_logic_vector(1 downto 0) := "11";

    constant CPU_FLAG_Z_BIT : integer := 3;
    constant CPU_FLAG_N_BIT : integer := 2;
    constant CPU_FLAG_H_BIT : integer := 1;
    constant CPU_FLAG_C_BIT : integer := 0;

    -- =========================================================================
    -- ALU operation encoding
    -- =========================================================================
    constant ALU_OP_ADD  : std_logic_vector(3 downto 0) := x"0";
    constant ALU_OP_SUB  : std_logic_vector(3 downto 0) := x"1";
    constant ALU_OP_AND  : std_logic_vector(3 downto 0) := x"2";
    constant ALU_OP_OR   : std_logic_vector(3 downto 0) := x"3";
    constant ALU_OP_XOR  : std_logic_vector(3 downto 0) := x"4";
    constant ALU_OP_CP   : std_logic_vector(3 downto 0) := x"5";
    constant ALU_OP_INC  : std_logic_vector(3 downto 0) := x"6";
    constant ALU_OP_DEC  : std_logic_vector(3 downto 0) := x"7";
    constant ALU_OP_ADC  : std_logic_vector(3 downto 0) := x"8";
    constant ALU_OP_SBC  : std_logic_vector(3 downto 0) := x"9";
    constant ALU_OP_DAA  : std_logic_vector(3 downto 0) := x"A";
    constant ALU_OP_PASS : std_logic_vector(3 downto 0) := x"F";

    -- =========================================================================
    -- Decoder instruction classes
    -- =========================================================================
    constant DEC_CLASS_NOP     : std_logic_vector(3 downto 0) := x"0";
    constant DEC_CLASS_LD_R_N  : std_logic_vector(3 downto 0) := x"1";
    constant DEC_CLASS_LD_R_R  : std_logic_vector(3 downto 0) := x"2";
    constant DEC_CLASS_LD_16_N : std_logic_vector(3 downto 0) := x"3";
    constant DEC_CLASS_ALU_R   : std_logic_vector(3 downto 0) := x"4";
    constant DEC_CLASS_INC_R   : std_logic_vector(3 downto 0) := x"5";
    constant DEC_CLASS_DEC_R   : std_logic_vector(3 downto 0) := x"6";
    constant DEC_CLASS_MEM_HL  : std_logic_vector(3 downto 0) := x"7";
    constant DEC_CLASS_JUMP    : std_logic_vector(3 downto 0) := x"8";
    constant DEC_CLASS_STACK   : std_logic_vector(3 downto 0) := x"9";
    constant DEC_CLASS_CONTROL : std_logic_vector(3 downto 0) := x"A";
    constant DEC_CLASS_LD_MEM  : std_logic_vector(3 downto 0) := x"B";
    constant DEC_CLASS_INC_16  : std_logic_vector(3 downto 0) := x"C";
    constant DEC_CLASS_DEC_16  : std_logic_vector(3 downto 0) := x"D";
    constant DEC_CLASS_ALU_N   : std_logic_vector(3 downto 0) := x"E";
    constant DEC_CLASS_UNKNOWN : std_logic_vector(3 downto 0) := x"F";

end package gb_types_pkg;
