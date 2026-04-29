-- =============================================================================
-- Module:      vga_test_top
-- Description: M1 test top-level — VGA color bar output via PLL
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-03-23
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Connects PLL, VGA controller, and color bar generator for hardware testing.
-- Directly drives VGA connector with 8 vertical color bars.
-- LEDs show status: LED0 = PLL locked, LED1 = vsync activity.
-- =============================================================================
-- Revision History:
-- 2026-03-23 - Initial creation for M1 hardware validation
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_test_top is
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
end entity vga_test_top;

architecture rtl of vga_test_top is

    -- PLL outputs
    signal clk_vga    : std_logic;
    signal clk_cpu    : std_logic;
    signal pll_locked : std_logic;
    signal pll_areset : std_logic;

    -- Reset synchronization (VGA domain)
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

    -- VSync edge detection for LED activity indicator
    signal vsync_prev : std_logic;
    signal vsync_cnt  : unsigned(5 downto 0);

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
    -- PLL: 50 MHz -> 25.175 MHz
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
    -- Hold reset until PLL is locked
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
    -- Color bar pattern generator
    -- =========================================================================
    u_color_bar: entity work.vga_color_bar
        port map (
            pixel_x   => pixel_x,
            visible   => visible,
            vga_r     => vga_r_i,
            vga_g     => vga_g_i,
            vga_b     => vga_b_i
        );

    -- The RZ-EasyFPGA A2.2 exposes one VGA pin per color channel. Dither the
    -- internal 3-bit level so lower intensity bits still affect the output.
    vga_r <= dither_channel(vga_r_i, pixel_x(0), pixel_y(0));
    vga_g <= dither_channel(vga_g_i, pixel_x(0), pixel_y(0));
    vga_b <= dither_channel(vga_b_i, pixel_x(0), pixel_y(0));

    -- =========================================================================
    -- Status LEDs
    -- =========================================================================
    -- VSync counter for LED1 blink (toggles every 32 frames ~ 0.5 Hz blink)
    p_vsync_activity: process(clk_vga)
    begin
        if rising_edge(clk_vga) then
            if reset_vga = '1' then
                vsync_prev <= '1';
                vsync_cnt  <= (others => '0');
            else
                vsync_prev <= vsync_i;
                -- Detect falling edge of vsync (start of vsync pulse)
                if vsync_prev = '1' and vsync_i = '0' then
                    vsync_cnt <= vsync_cnt + 1;
                end if;
            end if;
        end if;
    end process p_vsync_activity;

    -- LED0: PLL locked (on when locked, active-low LED)
    led(0) <= not pll_locked;
    -- LED1: VSync activity (blinks at ~1 Hz from frame counter MSB)
    led(1) <= not vsync_cnt(5);
    -- LED2-3: unused, off
    led(2) <= '1';
    led(3) <= '1';

end architecture rtl;
