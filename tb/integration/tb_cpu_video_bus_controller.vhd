-- =============================================================================
-- Module:      tb_cpu_video_bus_controller
-- Description: CPU + bus-controller self-check for framebuffer write sequence
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-13
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_cpu_video_bus_controller is
end entity tb_cpu_video_bus_controller;

architecture sim of tb_cpu_video_bus_controller is

    constant CLK_PERIOD : time := 20 ns;

    signal clk                : std_logic := '0';
    signal reset              : std_logic := '1';
    signal sim_done           : boolean := false;

    signal mem_addr           : std_logic_vector(15 downto 0);
    signal mem_data_in        : std_logic_vector(7 downto 0);
    signal mem_data_out       : std_logic_vector(7 downto 0);
    signal mem_read           : std_logic;
    signal mem_write          : std_logic;
    signal mem_ready          : std_logic;
    signal unsupported_opcode : std_logic;
    signal interrupt_ack      : std_logic;
    signal interrupt_vector   : std_logic_vector(2 downto 0);

    signal fb_we              : std_logic;
    signal fb_addr            : unsigned(14 downto 0);
    signal fb_data            : std_logic_vector(1 downto 0);
    signal led_pattern        : std_logic_vector(3 downto 0);
    signal display_digits     : std_logic_vector(15 downto 0);
    signal checker_failed     : std_logic;
    signal final_passed       : std_logic;
    signal bus_interrupt_enable : std_logic_vector(4 downto 0);
    signal bus_interrupt_flags  : std_logic_vector(4 downto 0);
    signal fb_write_count_dbg : std_logic_vector(7 downto 0);
    signal expected_index     : unsigned(7 downto 0);

    function expected_fb_addr(index_in : unsigned(7 downto 0)) return unsigned is
        variable index_v : integer;
        variable x_v     : integer;
        variable y_v     : integer;
        variable addr_v  : integer;
    begin
        index_v := to_integer(index_in);

        if index_v < 32 then
            x_v := 48 + index_v;
            y_v := 56 + (index_v / 2);
        elsif index_v < 64 then
            x_v := 80 + (index_v - 32);
            y_v := 88;
        else
            x_v := 0;
            y_v := 0;
        end if;

        addr_v := (y_v * 160) + x_v;
        return to_unsigned(addr_v, 15);
    end function expected_fb_addr;

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

    u_cpu: entity work.cpu
        port map (
            clk                => clk,
            reset              => reset,
            mem_addr           => mem_addr,
            mem_data_in        => mem_data_in,
            mem_data_out       => mem_data_out,
            mem_read           => mem_read,
            mem_write          => mem_write,
            mem_ready          => mem_ready,
            interrupt_enable   => bus_interrupt_enable,
            interrupt_flags    => bus_interrupt_flags,
            interrupt_ack      => interrupt_ack,
            interrupt_vector   => interrupt_vector,
            halted             => open,
            ime_out            => open,
            interrupt_pending  => open,
            unsupported_opcode => unsupported_opcode,
            debug_a            => open,
            debug_f            => open,
            debug_b            => open,
            debug_c            => open,
            debug_d            => open,
            debug_e            => open,
            debug_h            => open,
            debug_l            => open,
            debug_pc           => open,
            debug_sp           => open,
            debug_state        => open
        );

    u_bus: entity work.bus_controller
        port map (
            clk                  => clk,
            reset                => reset,
            cpu_addr             => mem_addr,
            cpu_data_in          => mem_data_in,
            cpu_data_out         => mem_data_out,
            cpu_read             => mem_read,
            cpu_write            => mem_write,
            cpu_ready            => mem_ready,
            unsupported_opcode   => unsupported_opcode,
            fb_clear_active      => '0',
            fb_clear_addr        => (others => '0'),
            fb_we                => fb_we,
            fb_addr              => fb_addr,
            fb_data              => fb_data,
            led_pattern          => led_pattern,
            display_digits       => display_digits,
            checker_failed       => checker_failed,
            final_passed         => final_passed,
            interrupt_ack        => interrupt_ack,
            interrupt_vector     => interrupt_vector,
            interrupt_enable     => bus_interrupt_enable,
            interrupt_flags      => bus_interrupt_flags,
            serial_debug_valid   => open,
            serial_debug_data    => open,
            debug_fb_write_count => fb_write_count_dbg
        );

    p_framebuffer_write_monitor: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                expected_index <= (others => '0');
            elsif fb_we = '1' then
                assert expected_index < to_unsigned(64, 8)
                    report "FAIL: CPU wrote more than 64 framebuffer pixels"
                    severity failure;

                assert fb_addr = expected_fb_addr(expected_index)
                    report "FAIL: framebuffer write address did not match expected smoke pattern"
                    severity failure;

                assert fb_data = "11"
                    report "FAIL: framebuffer write data should be black pixel value 3"
                    severity failure;

                expected_index <= expected_index + 1;
            end if;
        end if;
    end process p_framebuffer_write_monitor;

    p_stimulus: process
    begin
        report "=== tb_cpu_video_bus_controller: Starting simulation ===" severity note;

        reset <= '1';
        wait for CLK_PERIOD * 10;
        reset <= '0';

        wait for 1 ms;

        assert expected_index = to_unsigned(64, 8)
            report "FAIL: CPU did not write exactly 64 framebuffer pixels"
            severity failure;

        assert fb_write_count_dbg = x"40"
            report "FAIL: bus controller framebuffer write counter is not 64"
            severity failure;

        assert checker_failed = '0'
            report "FAIL: bus controller checker reported failure"
            severity failure;

        assert final_passed = '1'
            report "FAIL: bus controller did not raise final_passed"
            severity failure;

        assert led_pattern = x"D"
            report "FAIL: final LED checkpoint pattern should be D"
            severity failure;

        assert display_digits = x"1234"
            report "FAIL: display digits should be 1234 after pass code"
            severity failure;

        report "=== tb_cpu_video_bus_controller: ALL TESTS PASSED ===" severity note;
        sim_done <= true;
        wait;
    end process p_stimulus;

end architecture sim;
