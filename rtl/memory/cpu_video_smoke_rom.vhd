-- =============================================================================
-- Module:      cpu_video_smoke_rom
-- Description: Internal ROM image for the CPU-to-framebuffer smoke program
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-17
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-17 - Extracted smoke program from bus_controller
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpu_video_smoke_rom is
    port (
        addr : in  std_logic_vector(15 downto 0);
        data : out std_logic_vector(7 downto 0)
    );
end entity cpu_video_smoke_rom;

architecture rtl of cpu_video_smoke_rom is

    constant ROM_LAST_INDEX : integer := 280;

    type rom_t is array (0 to ROM_LAST_INDEX) of std_logic_vector(7 downto 0);
    constant ROM : rom_t := (
        x"31", x"FE", x"FF", x"21", x"80", x"FF", x"3E", x"01",
        x"77", x"3E", x"03", x"21", x"30", x"A3", x"77", x"21",
        x"31", x"A3", x"77", x"21", x"D2", x"A3", x"77", x"21",
        x"D3", x"A3", x"77", x"21", x"74", x"A4", x"77", x"21",
        x"75", x"A4", x"77", x"21", x"16", x"A5", x"77", x"21",
        x"17", x"A5", x"77", x"21", x"B8", x"A5", x"77", x"21",
        x"B9", x"A5", x"77", x"21", x"5A", x"A6", x"77", x"21",
        x"5B", x"A6", x"77", x"21", x"FC", x"A6", x"77", x"21",
        x"FD", x"A6", x"77", x"21", x"9E", x"A7", x"77", x"21",
        x"9F", x"A7", x"77", x"21", x"40", x"A8", x"77", x"21",
        x"41", x"A8", x"77", x"21", x"E2", x"A8", x"77", x"21",
        x"E3", x"A8", x"77", x"21", x"84", x"A9", x"77", x"21",
        x"85", x"A9", x"77", x"21", x"26", x"AA", x"77", x"21",
        x"27", x"AA", x"77", x"21", x"C8", x"AA", x"77", x"21",
        x"C9", x"AA", x"77", x"21", x"6A", x"AB", x"77", x"21",
        x"6B", x"AB", x"77", x"21", x"0C", x"AC", x"77", x"21",
        x"0D", x"AC", x"77", x"21", x"AE", x"AC", x"77", x"21",
        x"AF", x"AC", x"77", x"21", x"50", x"B7", x"77", x"21",
        x"51", x"B7", x"77", x"21", x"52", x"B7", x"77", x"21",
        x"53", x"B7", x"77", x"21", x"54", x"B7", x"77", x"21",
        x"55", x"B7", x"77", x"21", x"56", x"B7", x"77", x"21",
        x"57", x"B7", x"77", x"21", x"58", x"B7", x"77", x"21",
        x"59", x"B7", x"77", x"21", x"5A", x"B7", x"77", x"21",
        x"5B", x"B7", x"77", x"21", x"5C", x"B7", x"77", x"21",
        x"5D", x"B7", x"77", x"21", x"5E", x"B7", x"77", x"21",
        x"5F", x"B7", x"77", x"21", x"60", x"B7", x"77", x"21",
        x"61", x"B7", x"77", x"21", x"62", x"B7", x"77", x"21",
        x"63", x"B7", x"77", x"21", x"64", x"B7", x"77", x"21",
        x"65", x"B7", x"77", x"21", x"66", x"B7", x"77", x"21",
        x"67", x"B7", x"77", x"21", x"68", x"B7", x"77", x"21",
        x"69", x"B7", x"77", x"21", x"6A", x"B7", x"77", x"21",
        x"6B", x"B7", x"77", x"21", x"6C", x"B7", x"77", x"21",
        x"6D", x"B7", x"77", x"21", x"6E", x"B7", x"77", x"21",
        x"6F", x"B7", x"77", x"21", x"80", x"FF", x"3E", x"0D",
        x"77", x"21", x"81", x"FF", x"3E", x"A5", x"77", x"18",
        x"FE"
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
