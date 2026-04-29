-- =============================================================================
-- Module:      framebuffer
-- Description: Dual-port 160x144x2-bit framebuffer for Game Boy display
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-03-25
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- True dual-port RAM inferred as Cyclone IV M9K block RAM.
-- Port A (write): PPU writes 2-bit pixel data at clk_cpu (clk_a)
-- Port B (read):  VGA pipeline reads 2-bit pixel data at clk_vga (clk_b)
--
-- Memory layout: linear, addr = y * 160 + x
-- Total: 160 * 144 = 23,040 addresses x 2 bits = 46,080 bits (~5.6 KB)
-- Uses 6 M9K blocks (6 * 9,216 = 55,296 bits, 20% of available block RAM)
--
-- Address width: 15 bits (2^15 = 32,768 > 23,040)
-- Data width: 2 bits
-- =============================================================================
-- Revision History:
-- 2026-03-25 - Initial creation for M2 milestone
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity framebuffer is
    port (
        -- Port A: Write (PPU domain)
        clk_a    : in  std_logic;
        we_a     : in  std_logic;
        addr_a   : in  unsigned(14 downto 0);  -- 0..23039
        data_a   : in  std_logic_vector(1 downto 0);

        -- Port B: Read (VGA domain)
        clk_b    : in  std_logic;
        addr_b   : in  unsigned(14 downto 0);  -- 0..23039
        data_b   : out std_logic_vector(1 downto 0)
    );
end entity framebuffer;

architecture rtl of framebuffer is

    -- Total framebuffer size
    constant FB_SIZE : integer := 23040;  -- 160 * 144

    -- Block RAM array — Quartus infers M9K from this pattern
    type ram_type is array (0 to FB_SIZE - 1) of std_logic_vector(1 downto 0);
    signal ram : ram_type;

    -- Altera synthesis attributes to force block RAM inference
    attribute ramstyle : string;
    attribute ramstyle of ram : signal is "M9K";

begin

    -- Port A: write-only (PPU side)
    p_port_a: process(clk_a)
    begin
        if rising_edge(clk_a) then
            if we_a = '1' then
                ram(to_integer(addr_a)) <= data_a;
            end if;
        end if;
    end process p_port_a;

    -- Port B: read-only (VGA side)
    p_port_b: process(clk_b)
    begin
        if rising_edge(clk_b) then
            data_b <= ram(to_integer(addr_b));
        end if;
    end process p_port_b;

end architecture rtl;
