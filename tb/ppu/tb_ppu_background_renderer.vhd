-- =============================================================================
-- Module:      tb_ppu_background_renderer
-- Description: Self-checking testbench for background tile rendering and scroll
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
    signal lcd_enable : std_logic := '1';
    signal scroll_y   : std_logic_vector(7 downto 0) := x"00";
    signal scroll_x   : std_logic_vector(7 downto 0) := x"00";
    signal vram_addr  : unsigned(12 downto 0);
    signal vram_data  : std_logic_vector(7 downto 0);
    signal fb_we      : std_logic;
    signal fb_addr    : unsigned(14 downto 0);
    signal fb_data    : std_logic_vector(1 downto 0);
    signal current_line : unsigned(7 downto 0);
    signal current_dot  : unsigned(8 downto 0);
    signal line_active  : std_logic;
    signal line_done    : std_logic;
    signal ppu_mode     : std_logic_vector(1 downto 0);
    signal busy       : std_logic;
    signal done       : std_logic;
    signal vram_mem   : memory_t := init_vram;
    signal fb_mem     : framebuffer_t := (others => "00");
    signal line_count : integer range 0 to 144 := 0;
    signal seen_mode0 : std_logic := '0';
    signal seen_mode1 : std_logic := '0';
    signal seen_mode2 : std_logic := '0';
    signal seen_mode3 : std_logic := '0';
    signal mode2_dot_ok : std_logic := '0';
    signal mode3_dot_ok : std_logic := '0';
    signal mode0_dot_ok : std_logic := '0';
    signal mode1_dot_ok : std_logic := '0';

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
            lcd_enable => lcd_enable,
            scroll_y  => scroll_y,
            scroll_x  => scroll_x,
            vram_addr => vram_addr,
            vram_data => vram_data,
            fb_we     => fb_we,
            fb_addr   => fb_addr,
            fb_data   => fb_data,
            current_line => current_line,
            current_dot  => current_dot,
            line_active  => line_active,
            line_done    => line_done,
            ppu_mode     => ppu_mode,
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
            if reset = '1' then
                fb_mem <= (others => "00");
            elsif fb_we = '1' then
                fb_mem(to_integer(fb_addr)) <= fb_data;
            end if;
        end if;
    end process p_fb;

    p_line_count: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                line_count <= 0;
            elsif line_done = '1' then
                if line_count < 144 then
                    line_count <= line_count + 1;
                end if;
            end if;
        end if;
    end process p_line_count;

    p_mode_monitor: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                seen_mode0 <= '0';
                seen_mode1 <= '0';
                seen_mode2 <= '0';
                seen_mode3 <= '0';
                mode2_dot_ok <= '0';
                mode3_dot_ok <= '0';
                mode0_dot_ok <= '0';
                mode1_dot_ok <= '0';
            else
                case ppu_mode is
                    when "00" =>
                        seen_mode0 <= '1';
                        if current_dot >= to_unsigned(252, 9) and
                           current_dot <= to_unsigned(455, 9) and
                           current_line < to_unsigned(144, 8) then
                            mode0_dot_ok <= '1';
                        end if;
                    when "01" =>
                        seen_mode1 <= '1';
                        if current_line >= to_unsigned(144, 8) and
                           current_line <= to_unsigned(153, 8) and
                           current_dot <= to_unsigned(455, 9) then
                            mode1_dot_ok <= '1';
                        end if;
                    when "10" =>
                        seen_mode2 <= '1';
                        if current_dot <= to_unsigned(79, 9) and
                           current_line < to_unsigned(144, 8) then
                            mode2_dot_ok <= '1';
                        end if;
                    when "11" =>
                        seen_mode3 <= '1';
                        if current_dot >= to_unsigned(80, 9) and
                           current_dot <= to_unsigned(251, 9) and
                           current_line < to_unsigned(144, 8) then
                            mode3_dot_ok <= '1';
                        end if;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process p_mode_monitor;

    p_stimulus: process
    begin
        report "=== tb_ppu_background_renderer: Starting simulation ===" severity note;

        wait for CLK_PERIOD * 4;
        lcd_enable <= '0';
        reset <= '0';
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';
        wait for CLK_PERIOD * 16;
        wait for 1 ns;

        assert current_line = to_unsigned(0, 8)
            report "FAIL: LCD disabled should hold LY at zero"
            severity failure;
        assert current_dot = to_unsigned(0, 9)
            report "FAIL: LCD disabled should hold dot counter at zero"
            severity failure;
        assert ppu_mode = "00"
            report "FAIL: LCD disabled should report Mode 0"
            severity failure;
        assert busy = '0' and done = '0' and fb_we = '0'
            report "FAIL: LCD disabled should keep renderer inactive"
            severity failure;

        reset <= '1';
        lcd_enable <= '1';
        wait until rising_edge(clk);
        reset <= '0';
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        wait until done = '1';
        wait until rising_edge(clk);
        wait for 1 ns;

        assert line_count = 144
            report "FAIL: renderer should complete exactly 144 scanlines"
            severity failure;
        assert current_line = to_unsigned(153, 8)
            report "FAIL: renderer should finish on VBlank line 153"
            severity failure;
        assert seen_mode0 = '1' and seen_mode1 = '1' and
               seen_mode2 = '1' and seen_mode3 = '1'
            report "FAIL: renderer should expose modes 0, 1, 2, and 3"
            severity failure;
        assert mode2_dot_ok = '1' and mode3_dot_ok = '1' and
               mode0_dot_ok = '1' and mode1_dot_ok = '1'
            report "FAIL: renderer should expose dot-based mode windows"
            severity failure;
        assert current_dot = to_unsigned(455, 9)
            report "FAIL: renderer should finish at the last dot of the VBlank line"
            severity failure;
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

        reset <= '1';
        wait until rising_edge(clk);
        scroll_x <= x"08";
        scroll_y <= x"00";
        reset <= '0';
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        wait until done = '1';
        wait until rising_edge(clk);
        wait for 1 ns;

        assert line_count = 144
            report "FAIL: SCX render should complete exactly 144 scanlines"
            severity failure;
        assert seen_mode0 = '1' and seen_mode1 = '1' and
               seen_mode2 = '1' and seen_mode3 = '1'
            report "FAIL: SCX render should expose modes 0, 1, 2, and 3"
            severity failure;
        assert mode2_dot_ok = '1' and mode3_dot_ok = '1' and
               mode0_dot_ok = '1' and mode1_dot_ok = '1'
            report "FAIL: SCX render should expose dot-based mode windows"
            severity failure;
        assert fb_mem(0) = "00"
            report "FAIL: SCX=8 should move the first visible pixel into tile-map column 1"
            severity failure;
        assert fb_mem(8) = "00"
            report "FAIL: SCX=8 should move the first checkerboard tile out of the left edge"
            severity failure;

        reset <= '1';
        wait until rising_edge(clk);
        scroll_x <= x"00";
        scroll_y <= x"01";
        reset <= '0';
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        wait until done = '1';
        wait until rising_edge(clk);
        wait for 1 ns;

        assert line_count = 144
            report "FAIL: SCY render should complete exactly 144 scanlines"
            severity failure;
        assert seen_mode0 = '1' and seen_mode1 = '1' and
               seen_mode2 = '1' and seen_mode3 = '1'
            report "FAIL: SCY render should expose modes 0, 1, 2, and 3"
            severity failure;
        assert mode2_dot_ok = '1' and mode3_dot_ok = '1' and
               mode0_dot_ok = '1' and mode1_dot_ok = '1'
            report "FAIL: SCY render should expose dot-based mode windows"
            severity failure;
        assert fb_mem(0) = "00"
            report "FAIL: SCY=1 should move the first visible pixel to tile row 1"
            severity failure;
        assert fb_mem(1) = "11"
            report "FAIL: SCY=1 should invert the first checkerboard row"
            severity failure;

        report "=== tb_ppu_background_renderer: ALL TESTS PASSED ===" severity note;
        sim_done <= true;
        wait;
    end process p_stimulus;

end architecture sim;
