-- =============================================================================
-- Module:      cpu_ppu_background_demo_rom
-- Description: Internal ROM image for the CPU-authored PPU background demo
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-17
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-17 - Extracted CPU/PPU integration program from bus_controller
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpu_ppu_background_demo_rom is
    port (
        addr : in  std_logic_vector(15 downto 0);
        data : out std_logic_vector(7 downto 0)
    );
end entity cpu_ppu_background_demo_rom;

architecture rtl of cpu_ppu_background_demo_rom is

    constant ROM_LAST_INDEX : integer := 92;

    type rom_t is array (0 to ROM_LAST_INDEX) of std_logic_vector(7 downto 0);
    constant ROM : rom_t := (
        -- Initialize SP and clear tile 0 at 0x8000..0x800F.
        x"31", x"FE", x"FF", x"21", x"00", x"80", x"AF", x"06",
        x"10", x"22", x"05", x"20", x"FC",
        -- Write tile 1 checkerboard data at 0x8010..0x801F.
        x"21", x"10", x"80", x"3E", x"AA", x"22", x"22", x"3E",
        x"55", x"22", x"22", x"3E", x"AA", x"22", x"22", x"3E",
        x"55", x"22", x"22", x"3E", x"AA", x"22", x"22", x"3E",
        x"55", x"22", x"22", x"3E", x"AA", x"22", x"22", x"3E",
        x"55", x"22", x"22",
        -- Clear the complete 32x32 background map at 0x9800..0x9BFF.
        x"21", x"00", x"98", x"AF", x"06", x"04", x"0E", x"00",
        x"22", x"0D", x"20", x"FC", x"05", x"20", x"F7",
        -- Write an alternating first tile row: tile 1, tile 0, repeated.
        x"21", x"00", x"98", x"06", x"0A", x"3E", x"01", x"22",
        x"AF", x"22", x"05", x"20", x"F8",
        -- Apply first real background scroll settings.
        x"21", x"42", x"FF", x"36", x"01",
        x"21", x"43", x"FF", x"36", x"08",
        -- Signal completion through debug I/O at 0xFF80, then park forever.
        x"21", x"80", x"FF", x"36", x"01", x"18", x"FE"
    );

begin

    p_read: process(addr)
        variable addr_u : unsigned(15 downto 0);
    begin
        addr_u := unsigned(addr);
        if addr_u <= to_unsigned(ROM_LAST_INDEX, 16) then
            data <= ROM(to_integer(addr_u));
        else
            data <= x"00";
        end if;
    end process p_read;

end architecture rtl;
