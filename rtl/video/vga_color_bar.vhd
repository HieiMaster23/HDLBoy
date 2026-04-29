-- =============================================================================
-- Module:      vga_color_bar
-- Description: Static color bar pattern generator for VGA testing
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-03-23
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Generates 8 vertical color bars across the 640-pixel wide display.
-- Each bar is 80 pixels wide. Colors (left to right):
--   White, Yellow, Cyan, Green, Magenta, Red, Blue, Black
--
-- The OMDAZZ board uses a resistor DAC with 3 bits per R/G/B channel
-- (accent-level per channel), giving 512 possible colors.
-- =============================================================================
-- Revision History:
-- 2026-03-23 - Initial creation for M1 hardware validation
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_color_bar is
    port (
        -- Pixel coordinates from VGA controller
        pixel_x   : in  unsigned(9 downto 0);
        visible   : in  std_logic;

        -- RGB output (3 bits per channel for OMDAZZ resistor DAC)
        vga_r     : out std_logic_vector(2 downto 0);
        vga_g     : out std_logic_vector(2 downto 0);
        vga_b     : out std_logic_vector(2 downto 0)
    );
end entity vga_color_bar;

architecture rtl of vga_color_bar is

    -- Bar index derived from pixel_x (640 / 8 = 80 pixels per bar)
    signal bar_index : unsigned(2 downto 0);

begin

    -- Divide horizontal position into 8 bars (80 pixels each)
    -- pixel_x(9 downto 7) gives values 0..4 for 0..639 range
    -- but 640/128 = 5, so we use pixel_x / 80 instead
    -- For simplicity and low resource usage: divide by shifting
    -- 80 = 64 + 16, not a power of 2, so we use a simple comparison chain
    bar_index <= to_unsigned(0, 3) when pixel_x < 80 else
                 to_unsigned(1, 3) when pixel_x < 160 else
                 to_unsigned(2, 3) when pixel_x < 240 else
                 to_unsigned(3, 3) when pixel_x < 320 else
                 to_unsigned(4, 3) when pixel_x < 400 else
                 to_unsigned(5, 3) when pixel_x < 480 else
                 to_unsigned(6, 3) when pixel_x < 560 else
                 to_unsigned(7, 3);

    -- Color bar pattern (standard SMPTE-like order)
    -- Bar:      White  Yellow  Cyan   Green  Magenta  Red    Blue   Black
    -- R (3b):    111    111    000     000     111    111     000    000
    -- G (3b):    111    111    111     111     000    000     000    000
    -- B (3b):    111    000    111     000     111    000     111    000
    p_color: process(bar_index, visible)
    begin
        if visible = '0' then
            vga_r <= "000";
            vga_g <= "000";
            vga_b <= "000";
        else
            case bar_index is
                when "000" =>  -- White
                    vga_r <= "111"; vga_g <= "111"; vga_b <= "111";
                when "001" =>  -- Yellow
                    vga_r <= "111"; vga_g <= "111"; vga_b <= "000";
                when "010" =>  -- Cyan
                    vga_r <= "000"; vga_g <= "111"; vga_b <= "111";
                when "011" =>  -- Green
                    vga_r <= "000"; vga_g <= "111"; vga_b <= "000";
                when "100" =>  -- Magenta
                    vga_r <= "111"; vga_g <= "000"; vga_b <= "111";
                when "101" =>  -- Red
                    vga_r <= "111"; vga_g <= "000"; vga_b <= "000";
                when "110" =>  -- Blue
                    vga_r <= "000"; vga_g <= "000"; vga_b <= "111";
                when others => -- Black
                    vga_r <= "000"; vga_g <= "000"; vga_b <= "000";
            end case;
        end if;
    end process p_color;

end architecture rtl;
