-- =============================================================================
-- Module:      vga_pixel_pipeline
-- Description: 3x upscaling from framebuffer to VGA with palette mapping
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-03-25
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Reads 2-bit pixel data from the framebuffer and outputs RGB for VGA.
-- The address scaler assumes raster-ordered coordinates from `vga_controller`.
--
-- Upscaling: 160x144 -> 480x432 (3x integer scale), centered in 640x480
--   Horizontal: pixels 80..559 map to GB x 0..159  (gb_x = (pixel_x - 80) / 3)
--   Vertical:   pixels 24..455 map to GB y 0..143   (gb_y = (pixel_y - 24) / 3)
--   Outside this region: black border
--
-- Pipeline: 2-stage latency (1 cycle address calc, 1 cycle RAM read)
--   Stage 0: Compute framebuffer address from pixel coordinates
--   Stage 1: RAM delivers data (registered output from framebuffer)
--   Stage 2: Palette lookup on RAM output, drive RGB
--
-- Palette (classic DMG green-ish shades mapped to 3-bit RGB):
--   GB 00 (lightest) -> RGB (111, 111, 111) white
--   GB 01            -> RGB (101, 101, 101) light gray
--   GB 10            -> RGB (010, 010, 010) dark gray
--   GB 11 (darkest)  -> RGB (000, 000, 000) black
-- =============================================================================
-- Revision History:
-- 2026-03-25 - Initial creation for M2 milestone
-- 2026-05-20 - Replaced divide-by-3 multipliers with sequential scale counters
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_pixel_pipeline is
    port (
        clk_vga    : in  std_logic;
        reset      : in  std_logic;

        -- From VGA controller
        pixel_x    : in  unsigned(9 downto 0);  -- 0..799
        pixel_y    : in  unsigned(9 downto 0);  -- 0..524
        visible    : in  std_logic;

        -- Framebuffer read interface
        fb_addr    : out unsigned(14 downto 0);
        fb_data    : in  std_logic_vector(1 downto 0);

        -- RGB output to VGA pins
        vga_r      : out std_logic_vector(2 downto 0);
        vga_g      : out std_logic_vector(2 downto 0);
        vga_b      : out std_logic_vector(2 downto 0)
    );
end entity vga_pixel_pipeline;

architecture rtl of vga_pixel_pipeline is

    -- Display area constants (3x upscale centered in 640x480)
    constant H_OFFSET   : integer := 80;   -- (640 - 480) / 2
    constant V_OFFSET   : integer := 24;   -- (480 - 432) / 2
    constant H_END      : integer := 560;  -- H_OFFSET + 160*3
    constant V_END      : integer := 456;  -- V_OFFSET + 144*3
    constant GB_WIDTH   : integer := 160;

    constant LINE_STRIDE : unsigned(14 downto 0) := to_unsigned(GB_WIDTH, 15);

    -- Sequential scaler state. The VGA controller supplies pixels in raster
    -- order, so fixed 3x scaling can be tracked with modulo-3 phases instead
    -- of recomputing divisions for every pixel.
    signal gb_x_reg        : unsigned(7 downto 0);
    signal x_phase_reg     : integer range 0 to 2;
    signal y_base_reg      : unsigned(14 downto 0);
    signal y_phase_reg     : integer range 0 to 2;

    -- Pipeline stage 2 signals
    signal in_game_area_s2 : std_logic;
    signal visible_s2      : std_logic;

begin

    -- =========================================================================
    -- Stage 0: Address calculation (combinational -> registered in framebuffer)
    -- =========================================================================
    -- The address is tracked incrementally from raster-ordered VGA coordinates.
    -- This avoids per-pixel division by 3 and removes the inferred multiplier
    -- blocks Quartus created for the previous reciprocal-multiply approach.
    p_addr_calc: process(clk_vga)
        variable in_area_v : std_logic;
        variable gb_x_v    : unsigned(7 downto 0);
        variable x_phase_v : integer range 0 to 2;
        variable y_base_v  : unsigned(14 downto 0);
        variable y_phase_v : integer range 0 to 2;
    begin
        if rising_edge(clk_vga) then
            if reset = '1' then
                fb_addr      <= (others => '0');
                gb_x_reg     <= (others => '0');
                x_phase_reg  <= 0;
                y_base_reg   <= (others => '0');
                y_phase_reg  <= 0;
                in_game_area_s2 <= '0';
                visible_s2      <= '0';
            else
                gb_x_v := gb_x_reg;
                x_phase_v := x_phase_reg;
                y_base_v := y_base_reg;
                y_phase_v := y_phase_reg;

                if pixel_x = to_unsigned(0, pixel_x'length) then
                    gb_x_v := (others => '0');
                    x_phase_v := 0;

                    if pixel_y = to_unsigned(V_OFFSET, pixel_y'length) then
                        y_base_v := (others => '0');
                        y_phase_v := 0;
                    elsif pixel_y > to_unsigned(V_OFFSET, pixel_y'length) and
                          pixel_y < to_unsigned(V_END, pixel_y'length) then
                        if y_phase_reg = 2 then
                            y_base_v := y_base_reg + LINE_STRIDE;
                            y_phase_v := 0;
                        else
                            y_phase_v := y_phase_reg + 1;
                        end if;
                    end if;
                end if;

                if pixel_x >= to_unsigned(H_OFFSET, pixel_x'length) and
                   pixel_x < to_unsigned(H_END, pixel_x'length) and
                   pixel_y >= to_unsigned(V_OFFSET, pixel_y'length) and
                   pixel_y < to_unsigned(V_END, pixel_y'length) then
                    in_area_v := '1';
                else
                    in_area_v := '0';
                end if;

                if in_area_v = '1' then
                    if pixel_x = to_unsigned(H_OFFSET, pixel_x'length) then
                        gb_x_v := (others => '0');
                        x_phase_v := 0;
                    end if;

                    fb_addr <= y_base_v + resize(gb_x_v, 15);

                    if x_phase_v = 2 then
                        x_phase_v := 0;
                        if gb_x_v < to_unsigned(GB_WIDTH - 1, gb_x_v'length) then
                            gb_x_v := gb_x_v + 1;
                        end if;
                    else
                        x_phase_v := x_phase_v + 1;
                    end if;
                else
                    fb_addr <= (others => '0');
                end if;

                gb_x_reg <= gb_x_v;
                x_phase_reg <= x_phase_v;
                y_base_reg <= y_base_v;
                y_phase_reg <= y_phase_v;
                in_game_area_s2 <= in_area_v;
                visible_s2 <= visible;
            end if;
        end if;
    end process p_addr_calc;

    -- =========================================================================
    -- Stage 2: Palette lookup (fb_data is valid after RAM read latency)
    -- =========================================================================
    p_palette: process(clk_vga)
    begin
        if rising_edge(clk_vga) then
            if reset = '1' then
                vga_r <= "000";
                vga_g <= "000";
                vga_b <= "000";
            elsif visible_s2 = '0' then
                -- Blanking region: drive black
                vga_r <= "000";
                vga_g <= "000";
                vga_b <= "000";
            elsif in_game_area_s2 = '0' then
                -- Outside game area but in visible VGA: black border
                vga_r <= "000";
                vga_g <= "000";
                vga_b <= "000";
            else
                -- Map 2-bit Game Boy pixel to RGB
                case fb_data is
                    when "00" =>  -- Lightest (white)
                        vga_r <= "111";
                        vga_g <= "111";
                        vga_b <= "111";
                    when "01" =>  -- Light gray
                        vga_r <= "101";
                        vga_g <= "101";
                        vga_b <= "101";
                    when "10" =>  -- Dark gray
                        vga_r <= "010";
                        vga_g <= "010";
                        vga_b <= "010";
                    when others => -- Darkest (black)
                        vga_r <= "000";
                        vga_g <= "000";
                        vga_b <= "000";
                end case;
            end if;
        end if;
    end process p_palette;

end architecture rtl;
