-- =============================================================================
-- Module:      framebuffer_test_top
-- Description: M2 test top-level — framebuffer + upscaling + test pattern on VGA
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-03-25
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Connects PLL, VGA controller, framebuffer, pixel pipeline, and test pattern
-- writer. On power-up the test pattern is written to the framebuffer, then
-- the VGA output displays it with 3x upscaling and black borders.
--
-- LEDs: LED0 = PLL locked, LED1 = VSync blink, LED2 = pattern write done
-- =============================================================================
-- Revision History:
-- 2026-03-25 - Initial creation for M2 hardware validation
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity framebuffer_test_top is
    port (
        -- Clock and reset
        clk_50mhz  : in  std_logic;
        reset_n     : in  std_logic;

        -- VGA output
        vga_r       : out std_logic;
        vga_g       : out std_logic;
        vga_b       : out std_logic;
        vga_hsync   : out std_logic;
        vga_vsync   : out std_logic;

        -- Status LEDs (active-low)
        led         : out std_logic_vector(3 downto 0)
    );
end entity framebuffer_test_top;

architecture rtl of framebuffer_test_top is

    -- PLL outputs
    signal clk_vga    : std_logic;
    signal clk_cpu    : std_logic;
    signal pll_locked : std_logic;
    signal pll_areset : std_logic;

    -- Reset synchronization (VGA domain — used for pattern writer too in test)
    signal reset_meta : std_logic;
    signal reset_sync : std_logic;
    signal reset_vga  : std_logic;

    -- VGA controller outputs
    signal pixel_x    : unsigned(9 downto 0);
    signal pixel_y    : unsigned(9 downto 0);
    signal visible    : std_logic;
    signal hsync_i    : std_logic;
    signal vsync_i    : std_logic;
    signal vga_r_i    : std_logic_vector(2 downto 0);
    signal vga_g_i    : std_logic_vector(2 downto 0);
    signal vga_b_i    : std_logic_vector(2 downto 0);

    -- Framebuffer write port (from test pattern writer)
    signal fb_we_a    : std_logic;
    signal fb_addr_a  : unsigned(14 downto 0);
    signal fb_data_a  : std_logic_vector(1 downto 0);

    -- Framebuffer read port (from pixel pipeline)
    signal fb_addr_b  : unsigned(14 downto 0);
    signal fb_data_b  : std_logic_vector(1 downto 0);

    -- Test pattern status
    signal pattern_done : std_logic;

    -- VSync activity counter
    signal vsync_prev   : std_logic;
    signal vsync_cnt    : unsigned(5 downto 0);

    function dither_channel(
        level : std_logic_vector(2 downto 0);
        x0    : std_logic;
        y0    : std_logic)
        return std_logic is
    begin
        case level is
            when "111" =>
                return '1';
            when "101" =>
                return x0 or y0;
            when "010" =>
                return x0 and y0;
            when others =>
                return '0';
        end case;
    end function dither_channel;

begin

    pll_areset <= not reset_n;

    -- =========================================================================
    -- PLL: 50 MHz -> 25.175 MHz (c0) + 4.194 MHz (c1)
    -- =========================================================================
    u_pll: entity work.pll_core
        port map (
            areset => pll_areset,
            inclk0 => clk_50mhz,
            c0     => clk_vga,
            c1     => clk_cpu,
            locked => pll_locked
        );

    -- =========================================================================
    -- Reset synchronizer (VGA clock domain)
    -- =========================================================================
    p_reset_sync: process(clk_vga)
    begin
        if rising_edge(clk_vga) then
            reset_meta <= (not reset_n) or (not pll_locked);
            reset_sync <= reset_meta;
        end if;
    end process p_reset_sync;

    reset_vga <= reset_sync;

    -- =========================================================================
    -- VGA timing controller
    -- =========================================================================
    u_vga: entity work.vga_controller
        port map (
            clk_vga   => clk_vga,
            reset     => reset_vga,
            hsync     => hsync_i,
            vsync     => vsync_i,
            pixel_x   => pixel_x,
            pixel_y   => pixel_y,
            visible   => visible
        );

    vga_hsync <= hsync_i;
    vga_vsync <= vsync_i;

    -- =========================================================================
    -- Test pattern writer (fills framebuffer once after reset)
    -- Uses clk_vga for simplicity in this test (in real design, PPU uses clk_cpu)
    -- =========================================================================
    u_pattern: entity work.test_pattern_writer
        port map (
            clk     => clk_vga,
            reset   => reset_vga,
            fb_we   => fb_we_a,
            fb_addr => fb_addr_a,
            fb_data => fb_data_a,
            done    => pattern_done
        );

    -- =========================================================================
    -- Framebuffer (dual-port: write from pattern writer, read from pixel pipeline)
    -- =========================================================================
    u_framebuffer: entity work.framebuffer
        port map (
            clk_a   => clk_vga,
            we_a    => fb_we_a,
            addr_a  => fb_addr_a,
            data_a  => fb_data_a,
            clk_b   => clk_vga,
            addr_b  => fb_addr_b,
            data_b  => fb_data_b
        );

    -- =========================================================================
    -- Pixel pipeline (3x upscaling + palette)
    -- =========================================================================
    u_pixel_pipe: entity work.vga_pixel_pipeline
        port map (
            clk_vga => clk_vga,
            reset   => reset_vga,
            pixel_x => pixel_x,
            pixel_y => pixel_y,
            visible => visible,
            fb_addr => fb_addr_b,
            fb_data => fb_data_b,
            vga_r   => vga_r_i,
            vga_g   => vga_g_i,
            vga_b   => vga_b_i
        );

    -- The RZ-EasyFPGA A2.2 exposes one VGA pin per color channel. Dither the
    -- internal 3-bit level so lower intensity bits still affect the output.
    vga_r <= dither_channel(vga_r_i, pixel_x(0), pixel_y(0));
    vga_g <= dither_channel(vga_g_i, pixel_x(0), pixel_y(0));
    vga_b <= dither_channel(vga_b_i, pixel_x(0), pixel_y(0));

    -- =========================================================================
    -- Status LEDs
    -- =========================================================================
    p_vsync_activity: process(clk_vga)
    begin
        if rising_edge(clk_vga) then
            if reset_vga = '1' then
                vsync_prev <= '1';
                vsync_cnt  <= (others => '0');
            else
                vsync_prev <= vsync_i;
                if vsync_prev = '1' and vsync_i = '0' then
                    vsync_cnt <= vsync_cnt + 1;
                end if;
            end if;
        end if;
    end process p_vsync_activity;

    led(0) <= not pll_locked;       -- PLL locked
    led(1) <= not vsync_cnt(5);     -- VSync activity (~1 Hz blink)
    led(2) <= not pattern_done;     -- Pattern written
    led(3) <= '1';                  -- Unused, off

end architecture rtl;
