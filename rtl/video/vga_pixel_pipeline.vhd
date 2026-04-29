-- =============================================================================
-- Module:      vga_pixel_pipeline
-- Description: 3x upscaling from framebuffer to VGA with palette mapping
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-03-25
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Reads 2-bit pixel data from the framebuffer and outputs RGB for VGA.
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

    -- Pipeline stage 1 signals
    signal in_game_area_s1 : std_logic;
    signal visible_s1      : std_logic;

    -- Pipeline stage 2 signals
    signal in_game_area_s2 : std_logic;
    signal visible_s2      : std_logic;

    -- Division by 3 helper signals (exposed for debug/waveform viewing)
    signal gb_x : unsigned(7 downto 0);  -- 0..159
    signal gb_y : unsigned(7 downto 0);  -- 0..143

begin

    -- =========================================================================
    -- Stage 0: Address calculation (combinational -> registered in framebuffer)
    -- =========================================================================
    -- Divide by 3 using subtraction: (pixel - offset) / 3
    -- For synthesis efficiency, pixel_x and pixel_y arrive registered from
    -- vga_controller, so we have one full clock cycle for this computation.
    p_addr_calc: process(clk_vga)
        variable vx : unsigned(9 downto 0);
        variable vy : unsigned(9 downto 0);
        variable gx : unsigned(9 downto 0);
        variable gy : unsigned(9 downto 0);
        variable in_area : std_logic;
        -- Use variables so fb_addr can read the freshly computed values
        -- within the same clock cycle (signals would be delayed by 1 cycle)
        variable gx_div3 : unsigned(7 downto 0);
        variable gy_div3 : unsigned(7 downto 0);
    begin
        if rising_edge(clk_vga) then
            if reset = '1' then
                fb_addr          <= (others => '0');
                in_game_area_s1  <= '0';
                visible_s1       <= '0';
            else
                vx := pixel_x;
                vy := pixel_y;

                -- Check if current pixel is within the game display area
                if vx >= H_OFFSET and vx < H_END and
                   vy >= V_OFFSET and vy < V_END then
                    in_area := '1';
                else
                    in_area := '0';
                end if;

                in_game_area_s1 <= in_area;
                visible_s1      <= visible;

                if in_area = '1' then
                    -- Divide by 3: (pixel - offset) / 3
                    -- Using a lookup-free approach: multiply by 21845 and
                    -- shift right by 16 approximates /3, but for 10-bit values
                    -- a simpler approach works: (n * 171) >> 9 for n < 512
                    -- Since max value is 479 (< 512) this is exact enough.
                    gx := vx - H_OFFSET;
                    gy := vy - V_OFFSET;

                    gx_div3 := resize(
                        shift_right(gx * to_unsigned(171, 9), 9),
                        8);
                    gy_div3 := resize(
                        shift_right(gy * to_unsigned(171, 9), 9),
                        8);

                    -- Update signals for debug visibility
                    gb_x <= gx_div3;
                    gb_y <= gy_div3;

                    -- Address = gy_div3 * 160 + gx_div3
                    -- 160 = 128 + 32, so y*160 = y*128 + y*32 = (y<<7) + (y<<5)
                    fb_addr <= resize(
                        shift_left(resize(gy_div3, 15), 7) +
                        shift_left(resize(gy_div3, 15), 5) +
                        resize(gx_div3, 15),
                        15);
                else
                    fb_addr <= (others => '0');
                end if;
            end if;
        end if;
    end process p_addr_calc;

    -- =========================================================================
    -- Stage 1: Framebuffer read occurs externally (1 cycle latency)
    -- Pipeline the control signals to match
    -- =========================================================================
    p_pipeline_s2: process(clk_vga)
    begin
        if rising_edge(clk_vga) then
            if reset = '1' then
                in_game_area_s2 <= '0';
                visible_s2      <= '0';
            else
                in_game_area_s2 <= in_game_area_s1;
                visible_s2      <= visible_s1;
            end if;
        end if;
    end process p_pipeline_s2;

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
