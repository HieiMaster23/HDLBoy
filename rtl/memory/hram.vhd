-- =============================================================================
-- Module:      hram
-- Description: 128-byte synchronous High RAM block
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-21
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-21 - Initial inferable HRAM block for bus resource optimization
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hram is
    port (
        clk      : in  std_logic;
        we       : in  std_logic;
        addr     : in  unsigned(6 downto 0);
        data_in  : in  std_logic_vector(7 downto 0);
        data_out : out std_logic_vector(7 downto 0)
    );
end entity hram;

architecture rtl of hram is

    constant HRAM_SIZE : integer := 128;

    type ram_t is array (0 to HRAM_SIZE - 1) of std_logic_vector(7 downto 0);
    signal ram : ram_t;

    attribute ramstyle : string;
    attribute ramstyle of ram : signal is "M9K";

begin

    p_hram: process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                ram(to_integer(addr)) <= data_in;
            end if;

            data_out <= ram(to_integer(addr));
        end if;
    end process p_hram;

end architecture rtl;
