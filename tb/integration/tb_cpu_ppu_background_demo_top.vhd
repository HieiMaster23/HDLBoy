-- =============================================================================
-- Module:      tb_cpu_ppu_background_demo_top
-- Description: Integration test for CPU-authored VRAM to PPU video path
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-16
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_cpu_ppu_background_demo_top is
end entity tb_cpu_ppu_background_demo_top;

architecture sim of tb_cpu_ppu_background_demo_top is

    constant CLK_PERIOD : time := 20 ns;

    signal clk_50mhz  : std_logic := '0';
    signal reset_n    : std_logic := '0';
    signal key_n      : std_logic_vector(3 downto 0) := "1111";
    signal ps2_clk    : std_logic := '1';
    signal ps2_data   : std_logic := '1';
    signal vga_r      : std_logic;
    signal vga_g      : std_logic;
    signal vga_b      : std_logic;
    signal vga_hsync  : std_logic;
    signal vga_vsync  : std_logic;
    signal led        : std_logic_vector(3 downto 0);
    signal sim_done   : boolean := false;
    signal seen_white : std_logic;
    signal seen_black : std_logic;

begin

    p_clk: process
    begin
        while not sim_done loop
            clk_50mhz <= '0';
            wait for CLK_PERIOD / 2;
            clk_50mhz <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process p_clk;

    u_dut: entity work.cpu_ppu_background_demo_top
        port map (
            clk_50mhz => clk_50mhz,
            reset_n   => reset_n,
            key_n     => key_n,
            ps2_clk   => ps2_clk,
            ps2_data  => ps2_data,
            vga_r     => vga_r,
            vga_g     => vga_g,
            vga_b     => vga_b,
            vga_hsync => vga_hsync,
            vga_vsync => vga_vsync,
            led       => led
        );

    p_video_monitor: process(clk_50mhz)
    begin
        if rising_edge(clk_50mhz) then
            if reset_n = '0' then
                seen_white <= '0';
                seen_black <= '0';
            else
                if vga_r = '1' and vga_g = '1' and vga_b = '1' then
                    seen_white <= '1';
                elsif vga_r = '0' and vga_g = '0' and vga_b = '0' then
                    seen_black <= '1';
                end if;
            end if;
        end if;
    end process p_video_monitor;

    p_stimulus: process
    begin
        report "=== tb_cpu_ppu_background_demo_top: Starting simulation ===" severity note;

        reset_n <= '0';
        wait for CLK_PERIOD * 10;
        reset_n <= '1';

        wait for 80 ms;

        assert led(1) = '0'
            report "FAIL: CPU did not finish authoring VRAM"
            severity failure;
        assert led(2) = '0'
            report "FAIL: PPU did not finish rendering CPU-authored VRAM"
            severity failure;
        assert seen_white = '1'
            report "FAIL: VGA output never produced white pixels"
            severity failure;
        assert seen_black = '1'
            report "FAIL: VGA output never produced black pixels"
            severity failure;

        report "=== tb_cpu_ppu_background_demo_top: ALL TESTS PASSED ===" severity note;
        sim_done <= true;
        wait;
    end process p_stimulus;

end architecture sim;
