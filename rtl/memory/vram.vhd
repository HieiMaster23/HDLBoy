-- =============================================================================
-- Module:      vram
-- Description: 8 KiB dual-port VRAM block for CPU writes and future PPU reads
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-16
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-16 - Initial VRAM slice for the first real PPU foundation
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vram is
    port (
        clk          : in  std_logic;

        cpu_we       : in  std_logic;
        cpu_addr     : in  unsigned(12 downto 0);
        cpu_data_in  : in  std_logic_vector(7 downto 0);
        cpu_data_out : out std_logic_vector(7 downto 0);

        ppu_addr     : in  unsigned(12 downto 0);
        ppu_data_out : out std_logic_vector(7 downto 0)
    );
end entity vram;

architecture rtl of vram is

    constant VRAM_SIZE : integer := 8192;

    type ram_t is array (0 to VRAM_SIZE - 1) of std_logic_vector(7 downto 0);
    signal ram : ram_t;

    attribute ramstyle : string;
    attribute ramstyle of ram : signal is "M9K";

begin

    p_vram: process(clk)
    begin
        if rising_edge(clk) then
            if cpu_we = '1' then
                ram(to_integer(cpu_addr)) <= cpu_data_in;
            end if;

            cpu_data_out <= ram(to_integer(cpu_addr));
            ppu_data_out <= ram(to_integer(ppu_addr));
        end if;
    end process p_vram;

end architecture rtl;
