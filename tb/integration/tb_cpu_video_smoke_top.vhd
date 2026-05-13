-- =============================================================================
-- Module:      tb_cpu_video_smoke_top
-- Description: Testbench for CPU-to-framebuffer VGA smoke top
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-13
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_cpu_video_smoke_top is
end entity tb_cpu_video_smoke_top;

architecture sim of tb_cpu_video_smoke_top is

    constant CLK_PERIOD : time := 20 ns;

    signal clk_50mhz : std_logic := '0';
    signal reset_n   : std_logic := '0';
    signal key_n     : std_logic_vector(3 downto 0) := "1111";
    signal vga_r     : std_logic;
    signal vga_g     : std_logic;
    signal vga_b     : std_logic;
    signal vga_hsync : std_logic;
    signal vga_vsync : std_logic;
    signal led       : std_logic_vector(3 downto 0);
    signal seg       : std_logic_vector(7 downto 0);
    signal digit_n   : std_logic_vector(3 downto 0);
    signal sim_done  : boolean := false;

    signal seen_digit_1 : std_logic;
    signal seen_digit_2 : std_logic;
    signal seen_digit_3 : std_logic;
    signal seen_digit_4 : std_logic;
    signal seen_white   : std_logic;
    signal seen_black   : std_logic;

    function seg_is_1(seg_in : std_logic_vector(7 downto 0)) return boolean is
    begin
        return seg_in(1) = '0' and seg_in(2) = '0' and
               seg_in(0) = '1' and seg_in(3) = '1' and
               seg_in(4) = '1' and seg_in(5) = '1' and
               seg_in(6) = '1' and seg_in(7) = '1';
    end function seg_is_1;

    function seg_is_2(seg_in : std_logic_vector(7 downto 0)) return boolean is
    begin
        return seg_in(0) = '0' and seg_in(1) = '0' and
               seg_in(3) = '0' and seg_in(4) = '0' and
               seg_in(6) = '0' and seg_in(2) = '1' and
               seg_in(5) = '1' and seg_in(7) = '1';
    end function seg_is_2;

    function seg_is_3(seg_in : std_logic_vector(7 downto 0)) return boolean is
    begin
        return seg_in(0) = '0' and seg_in(1) = '0' and
               seg_in(2) = '0' and seg_in(3) = '0' and
               seg_in(6) = '0' and seg_in(4) = '1' and
               seg_in(5) = '1' and seg_in(7) = '1';
    end function seg_is_3;

    function seg_is_4(seg_in : std_logic_vector(7 downto 0)) return boolean is
    begin
        return seg_in(1) = '0' and seg_in(2) = '0' and
               seg_in(5) = '0' and seg_in(6) = '0' and
               seg_in(0) = '1' and seg_in(3) = '1' and
               seg_in(4) = '1' and seg_in(7) = '1';
    end function seg_is_4;

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

    u_dut: entity work.cpu_video_smoke_top
        port map (
            clk_50mhz => clk_50mhz,
            reset_n   => reset_n,
            key_n     => key_n,
            vga_r     => vga_r,
            vga_g     => vga_g,
            vga_b     => vga_b,
            vga_hsync => vga_hsync,
            vga_vsync => vga_vsync,
            led       => led,
            seg       => seg,
            digit_n   => digit_n
        );

    p_display_monitor: process(clk_50mhz)
    begin
        if rising_edge(clk_50mhz) then
            if reset_n = '0' or key_n /= "1111" then
                seen_digit_1 <= '0';
                seen_digit_2 <= '0';
                seen_digit_3 <= '0';
                seen_digit_4 <= '0';
            else
                if digit_n = "1110" and seg_is_1(seg) then
                    seen_digit_1 <= '1';
                elsif digit_n = "1101" and seg_is_2(seg) then
                    seen_digit_2 <= '1';
                elsif digit_n = "1011" and seg_is_3(seg) then
                    seen_digit_3 <= '1';
                elsif digit_n = "0111" and seg_is_4(seg) then
                    seen_digit_4 <= '1';
                end if;
            end if;
        end if;
    end process p_display_monitor;

    p_video_monitor: process(clk_50mhz)
    begin
        if rising_edge(clk_50mhz) then
            if reset_n = '0' or key_n /= "1111" then
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
        report "=== tb_cpu_video_smoke_top: Starting simulation ===" severity note;

        reset_n <= '0';
        wait for CLK_PERIOD * 10;
        reset_n <= '1';

        wait for 8 ms;

        assert led = "0010"
            report "FAIL: LEDs should show the final CPU video checkpoint pattern D"
            severity failure;

        assert seen_digit_1 = '1' and seen_digit_2 = '1' and
               seen_digit_3 = '1' and seen_digit_4 = '1'
            report "FAIL: seven-segment display did not scan 1234"
            severity failure;

        assert seen_white = '1'
            report "FAIL: VGA output never produced white framebuffer pixels"
            severity failure;

        assert seen_black = '1'
            report "FAIL: VGA output never produced black pixels"
            severity failure;

        report "=== tb_cpu_video_smoke_top: ALL TESTS PASSED ===" severity note;
        sim_done <= true;
        wait;
    end process p_stimulus;

end architecture sim;
