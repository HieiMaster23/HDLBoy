-- =============================================================================
-- Module:      test_pattern_writer
-- Description: Writes a static test pattern into the framebuffer for M2 demo
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-03-25
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- On reset release, fills the 160x144 framebuffer with a recognizable pattern:
--   - 4 horizontal bands (36 rows each), one per shade (00, 01, 10, 11)
--   - A checkerboard overlay on the center 80x72 region
--   - An 8-pixel border in shade 11 (darkest) around the full screen edge
--
-- Once writing is complete, the 'done' output goes high and stays high.
-- Writing takes 23,040 clock cycles (one pixel per cycle).
-- =============================================================================
-- Revision History:
-- 2026-03-25 - Initial creation for M2 hardware validation
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity test_pattern_writer is
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;

        -- Framebuffer write interface
        fb_we    : out std_logic;
        fb_addr  : out unsigned(14 downto 0);
        fb_data  : out std_logic_vector(1 downto 0);

        -- Status
        done     : out std_logic
    );
end entity test_pattern_writer;

architecture rtl of test_pattern_writer is

    constant GB_WIDTH  : integer := 160;
    constant GB_HEIGHT : integer := 144;
    constant FB_SIZE   : integer := GB_WIDTH * GB_HEIGHT;  -- 23040

    -- Current pixel counter
    signal pixel_cnt : unsigned(14 downto 0);
    signal writing   : std_logic;

    -- Current x, y derived from pixel_cnt
    signal cur_x : unsigned(7 downto 0);
    signal cur_y : unsigned(7 downto 0);

begin

    -- Derive x, y from linear address
    -- x = pixel_cnt mod 160, y = pixel_cnt / 160
    -- For synthesis: use counter-based approach instead of division
    p_write: process(clk)
        variable x_cnt : unsigned(7 downto 0);
        variable y_cnt : unsigned(7 downto 0);
        variable shade : std_logic_vector(1 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                pixel_cnt <= (others => '0');
                cur_x     <= (others => '0');
                cur_y     <= (others => '0');
                writing   <= '1';
                fb_we     <= '0';
                fb_addr   <= (others => '0');
                fb_data   <= "00";
                done      <= '0';
            elsif writing = '1' then
                x_cnt := cur_x;
                y_cnt := cur_y;

                -- Determine pixel shade based on position
                -- Default: horizontal bands (4 bands of 36 rows)
                if y_cnt < 36 then
                    shade := "00";  -- lightest
                elsif y_cnt < 72 then
                    shade := "01";
                elsif y_cnt < 108 then
                    shade := "10";
                else
                    shade := "11";  -- darkest
                end if;

                -- Border: 8-pixel dark border around entire screen
                if x_cnt < 8 or x_cnt >= 152 or
                   y_cnt < 8 or y_cnt >= 136 then
                    shade := "11";
                end if;

                -- Checkerboard in center region (40..119 x, 36..107 y)
                if x_cnt >= 40 and x_cnt < 120 and
                   y_cnt >= 36 and y_cnt < 108 then
                    -- 8x8 checkerboard pattern
                    if (x_cnt(3) xor y_cnt(3)) = '1' then
                        shade := "00";
                    else
                        shade := "11";
                    end if;
                end if;

                -- Write this pixel
                fb_we   <= '1';
                fb_addr <= pixel_cnt;
                fb_data <= shade;

                -- Advance position
                if x_cnt = GB_WIDTH - 1 then
                    cur_x <= (others => '0');
                    cur_y <= y_cnt + 1;
                else
                    cur_x <= x_cnt + 1;
                end if;

                pixel_cnt <= pixel_cnt + 1;

                -- Check if we've written all pixels
                if pixel_cnt = FB_SIZE - 1 then
                    writing <= '0';
                    done    <= '1';
                end if;
            else
                -- Done writing
                fb_we <= '0';
            end if;
        end if;
    end process p_write;

end architecture rtl;
