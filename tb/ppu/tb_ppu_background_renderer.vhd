-- =============================================================================
-- Module:      tb_ppu_background_renderer
-- Description: Self-checking testbench for static background tile rendering
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-16
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_ppu_background_renderer is
end entity tb_ppu_background_renderer;

architecture sim of tb_ppu_background_renderer is

    constant CLK_PERIOD : time := 20 ns;

    type memory_t is array (0 to 8191) of std_logic_vector(7 downto 0);
    type framebuffer_t is array (0 to 23039) of std_logic_vector(1 downto 0);

    function init_vram return memory_t is
        variable mem_v : memory_t := (others => x"00");
    begin
        -- Tile 1: alternating black/white checkerboard.
        for row in 0 to 7 loop
            if (row mod 2) = 0 then
                mem_v(16 + row * 2) := x"AA";
                mem_v(16 + row * 2 + 1) := x"AA";
            else
                mem_v(16 + row * 2) := x"55";
                mem_v(16 + row * 2 + 1) := x"55";
            end if;
        end loop;

        mem_v(16#1800#) := x"01";
        return mem_v;
    end function init_vram;

    signal clk        : std_logic := '0';
    signal sim_done   : boolean := false;
    signal reset      : std_logic := '1';
    signal start      : std_logic := '0';
    signal vram_addr  : unsigned(12 downto 0);
    signal vram_data  : std_logic_vector(7 downto 0);
    signal fb_we      : std_logic;
    signal fb_addr    : unsigned(14 downto 0);
    signal fb_data    : std_logic_vector(1 downto 0);
    signal busy       : std_logic;
    signal done       : std_logic;
    signal vram_mem   : memory_t := init_vram;
    signal fb_mem     : framebuffer_t := (others => "00");

begin

    p_clk: process
    begin
        while not sim_done loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process p_clk;

    u_dut: entity work.ppu_background_renderer
        port map (
            clk       => clk,
            reset     => reset,
            start     => start,
            vram_addr => vram_addr,
            vram_data => vram_data,
            fb_we     => fb_we,
            fb_addr   => fb_addr,
            fb_data   => fb_data,
            busy      => busy,
            done      => done
        );

    p_vram: process(clk)
    begin
        if rising_edge(clk) then
            vram_data <= vram_mem(to_integer(vram_addr));
        end if;
    end process p_vram;

    p_fb: process(clk)
    begin
        if rising_edge(clk) then
            if fb_we = '1' then
                fb_mem(to_integer(fb_addr)) <= fb_data;
            end if;
        end if;
    end process p_fb;

    p_stimulus: process
    begin
        report "=== tb_ppu_background_renderer: Starting simulation ===" severity note;

        wait for CLK_PERIOD * 4;
        reset <= '0';
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        wait until done = '1';
        wait until rising_edge(clk);
        wait for 1 ns;

        assert fb_mem(0) = "11"
            report "FAIL: first checkerboard pixel should be black"
            severity failure;
        assert fb_mem(1) = "00"
            report "FAIL: second checkerboard pixel should be white"
            severity failure;
        assert fb_mem(160) = "00"
            report "FAIL: first pixel of second row should invert checkerboard"
            severity failure;
        assert fb_mem(161) = "11"
            report "FAIL: second pixel of second row should invert checkerboard"
            severity failure;
        assert fb_mem(23039) = "00"
            report "FAIL: pixels outside initialized tile map should use tile 0"
            severity failure;

        report "=== tb_ppu_background_renderer: ALL TESTS PASSED ===" severity note;
        sim_done <= true;
        wait;
    end process p_stimulus;

end architecture sim;
