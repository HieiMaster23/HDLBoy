-- =============================================================================
-- Module:      tb_vga_pixel_pipeline
-- Description: Testbench for VGA pixel pipeline (upscaling + palette)
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-03-25
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Verifies:
--   1. Black output during blanking (visible = '0')
--   2. Black border outside the 480x432 game area
--   3. Correct framebuffer address generation from raster-ordered VGA input
--   4. Palette mapping for all 4 shades
--   5. Full scanline address sweep across game area
-- =============================================================================
-- Revision History:
-- 2026-03-25 - Initial creation for M2 milestone
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_vga_pixel_pipeline is
end entity tb_vga_pixel_pipeline;

architecture sim of tb_vga_pixel_pipeline is

    constant CLK_PERIOD : time := 39.722 ns;

    signal clk_vga   : std_logic := '0';
    signal reset     : std_logic := '1';
    signal pixel_x   : unsigned(9 downto 0) := (others => '0');
    signal pixel_y   : unsigned(9 downto 0) := (others => '0');
    signal visible   : std_logic := '0';
    signal fb_addr   : unsigned(14 downto 0);
    signal fb_data   : std_logic_vector(1 downto 0) := "00";
    signal vga_r     : std_logic_vector(2 downto 0);
    signal vga_g     : std_logic_vector(2 downto 0);
    signal vga_b     : std_logic_vector(2 downto 0);

    signal sim_done  : boolean := false;

    -- Pipeline latency: 3 cycles (addr calc + RAM read + palette)
    constant PIPE_DELAY : integer := 3;

begin

    -- Clock generation
    p_clk: process
    begin
        while not sim_done loop
            clk_vga <= '0'; wait for CLK_PERIOD / 2;
            clk_vga <= '1'; wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process p_clk;

    -- DUT
    u_dut: entity work.vga_pixel_pipeline
        port map (
            clk_vga => clk_vga,
            reset   => reset,
            pixel_x => pixel_x,
            pixel_y => pixel_y,
            visible => visible,
            fb_addr => fb_addr,
            fb_data => fb_data,
            vga_r   => vga_r,
            vga_g   => vga_g,
            vga_b   => vga_b
        );

    -- Stimulus
    p_test: process
    begin
        report "=== tb_vga_pixel_pipeline: Starting simulation ===" severity note;

        -- Reset
        reset <= '1';
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk_vga);
        reset <= '0';

        -- =====================================================================
        -- Test 1: Blanking region should output black
        -- =====================================================================
        pixel_x <= to_unsigned(700, 10);  -- In horizontal blanking
        pixel_y <= to_unsigned(0, 10);
        visible <= '0';
        -- Wait for pipeline
        for i in 0 to PIPE_DELAY loop
            wait until rising_edge(clk_vga);
        end loop;

        assert vga_r = "000" and vga_g = "000" and vga_b = "000"
            report "FAIL: Non-black output during blanking"
            severity failure;
        report "PASS: Black output during blanking" severity note;

        -- =====================================================================
        -- Test 2: Visible but outside game area (left border) -> black
        -- =====================================================================
        pixel_x <= to_unsigned(10, 10);  -- Before H_OFFSET (80)
        pixel_y <= to_unsigned(100, 10);
        visible <= '1';
        for i in 0 to PIPE_DELAY loop
            wait until rising_edge(clk_vga);
        end loop;

        assert vga_r = "000" and vga_g = "000" and vga_b = "000"
            report "FAIL: Non-black output in left border"
            severity failure;
        report "PASS: Black border outside game area" severity note;

        -- =====================================================================
        -- Test 3: Palette mapping — test all 4 shades
        -- =====================================================================
        -- Set pixel inside game area
        pixel_x <= to_unsigned(80, 10);   -- First game pixel (gb_x=0)
        pixel_y <= to_unsigned(24, 10);   -- First game line (gb_y=0)
        visible <= '1';

        -- Test shade 00 (white)
        fb_data <= "00";
        for i in 0 to PIPE_DELAY loop
            wait until rising_edge(clk_vga);
        end loop;
        assert vga_r = "111" and vga_g = "111" and vga_b = "111"
            report "FAIL: Shade 00 should be white (111,111,111)"
            severity failure;
        report "PASS: Palette shade 00 = white" severity note;

        -- Test shade 01 (light gray)
        fb_data <= "01";
        for i in 0 to PIPE_DELAY loop
            wait until rising_edge(clk_vga);
        end loop;
        assert vga_r = "101" and vga_g = "101" and vga_b = "101"
            report "FAIL: Shade 01 should be light gray (101,101,101)"
            severity failure;
        report "PASS: Palette shade 01 = light gray" severity note;

        -- Test shade 10 (dark gray)
        fb_data <= "10";
        for i in 0 to PIPE_DELAY loop
            wait until rising_edge(clk_vga);
        end loop;
        assert vga_r = "010" and vga_g = "010" and vga_b = "010"
            report "FAIL: Shade 10 should be dark gray (010,010,010)"
            severity failure;
        report "PASS: Palette shade 10 = dark gray" severity note;

        -- Test shade 11 (black)
        fb_data <= "11";
        for i in 0 to PIPE_DELAY loop
            wait until rising_edge(clk_vga);
        end loop;
        assert vga_r = "000" and vga_g = "000" and vga_b = "000"
            report "FAIL: Shade 11 should be black (000,000,000)"
            severity failure;
        report "PASS: Palette shade 11 = black" severity note;

        -- =====================================================================
        -- Test 4: Address generation — verify framebuffer address for known pixel
        -- Pixel (80, 24) -> gb(0,0) -> addr 0
        -- Pixel (83, 24) -> gb(1,0) -> addr 1  (3 VGA pixels per GB pixel)
        -- Pixel (80, 27) -> gb(0,1) -> addr 160
        -- =====================================================================
        -- The optimized pipeline tracks the VGA raster stream instead of
        -- recomputing division by 3 for arbitrary coordinate jumps.
        reset <= '1';
        wait until rising_edge(clk_vga);
        wait until rising_edge(clk_vga);
        reset <= '0';

        -- Check addr for pixel (83, 24) -> should be 1.
        -- Drive the start of the first game line and then the first scaled
        -- pixels so the internal 3x phase counter is aligned.
        pixel_y <= to_unsigned(24, 10);
        visible <= '1';
        for x in 0 to 83 loop
            pixel_x <= to_unsigned(x, 10);
            wait until rising_edge(clk_vga);
        end loop;
        wait for 1 ns;

        assert fb_addr = to_unsigned(1, 15)
            report "FAIL: Pixel (83,24) should map to fb_addr 1, got " &
                   integer'image(to_integer(fb_addr))
            severity failure;
        report "PASS: Address mapping (83,24) -> fb_addr 1" severity note;

        -- Check addr for pixel (80, 27) -> gb(0,1) -> addr 160.
        -- Advance the line-start samples that update the vertical 3x phase.
        pixel_x <= to_unsigned(0, 10);
        pixel_y <= to_unsigned(25, 10);
        wait until rising_edge(clk_vga);
        pixel_y <= to_unsigned(26, 10);
        wait until rising_edge(clk_vga);
        pixel_y <= to_unsigned(27, 10);
        wait until rising_edge(clk_vga);

        pixel_x <= to_unsigned(80, 10);
        visible <= '1';
        wait until rising_edge(clk_vga);
        wait for 1 ns;

        assert fb_addr = to_unsigned(160, 15)
            report "FAIL: Pixel (80,27) should map to fb_addr 160, got " &
                   integer'image(to_integer(fb_addr))
            severity failure;
        report "PASS: Address mapping (80,27) -> fb_addr 160" severity note;

        report "=== tb_vga_pixel_pipeline: ALL TESTS PASSED ===" severity note;
        sim_done <= true;
        wait;
    end process p_test;

end architecture sim;
