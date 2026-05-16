-- =============================================================================
-- Module:      tb_timer
-- Description: Self-checking testbench for the DMG timer block
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-14
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_timer is
end entity tb_timer;

architecture sim of tb_timer is

    constant CLK_PERIOD : time := 20 ns;

    signal clk : std_logic := '0';
    signal reset : std_logic := '1';
    signal write_data : std_logic_vector(7 downto 0) := x"00";
    signal write_div : std_logic := '0';
    signal write_tima : std_logic := '0';
    signal write_tma : std_logic := '0';
    signal write_tac : std_logic := '0';
    signal div_read : std_logic_vector(7 downto 0);
    signal tima_read : std_logic_vector(7 downto 0);
    signal tma_read : std_logic_vector(7 downto 0);
    signal tac_read : std_logic_vector(7 downto 0);
    signal timer_interrupt_set : std_logic;
    signal sim_done : boolean := false;

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

    u_dut: entity work.timer
        generic map (
            G_DIV_COUNTER_STEP => 4,
            G_DIV_COUNTER_RESET => 4
        )
        port map (
            clk => clk,
            reset => reset,
            write_data => write_data,
            write_div => write_div,
            write_tima => write_tima,
            write_tma => write_tma,
            write_tac => write_tac,
            div_read => div_read,
            tima_read => tima_read,
            tma_read => tma_read,
            tac_read => tac_read,
            timer_interrupt_set => timer_interrupt_set
        );

    p_stimulus: process
        procedure wait_cycles(constant count_in : in integer) is
        begin
            for i in 1 to count_in loop
                wait until rising_edge(clk);
                wait for 1 ns;
            end loop;
        end procedure wait_cycles;

        procedure write_reg(
            signal strobe_out : out std_logic;
            constant value_in : in std_logic_vector(7 downto 0)) is
        begin
            write_data <= value_in;
            strobe_out <= '1';
            wait until rising_edge(clk);
            wait for 1 ns;
            strobe_out <= '0';
        end procedure write_reg;
    begin
        report "=== tb_timer: Starting simulation ===" severity note;

        reset <= '1';
        wait_cycles(4);
        reset <= '0';
        wait_cycles(1);

        assert tima_read = x"00" and tma_read = x"00" and tac_read = x"F8"
            report "FAIL: timer reset values are incorrect"
            severity failure;

        write_reg(write_tima, x"AA");
        write_reg(write_tma, x"55");
        write_reg(write_div, x"00");
        write_reg(write_tac, x"05");

        assert tima_read = x"AA" and tma_read = x"55" and tac_read = x"FD"
            report "FAIL: timer registers should read back written values"
            severity failure;

        wait_cycles(1);
        assert tima_read = x"AA"
            report "FAIL: TIMA should not increment before the selected divider falling edge"
            severity failure;

        wait_cycles(1);
        assert tima_read = x"AB"
            report "FAIL: TIMA should increment on TAC-selected divider falling edge"
            severity failure;

        write_reg(write_tac, x"00");
        write_reg(write_div, x"00");
        write_reg(write_tima, x"FF");
        write_reg(write_tma, x"42");
        write_reg(write_div, x"00");
        write_reg(write_tac, x"05");

        wait_cycles(3);
        assert tima_read = x"00" and timer_interrupt_set = '0'
            report "FAIL: TIMA overflow should hold 0x00 before reload"
            severity failure;

        wait_cycles(1);
        assert tima_read = x"42" and timer_interrupt_set = '1'
            report "FAIL: TIMA should reload TMA and pulse interrupt one M-cycle after overflow"
            severity failure;

        wait_cycles(1);
        assert timer_interrupt_set = '0'
            report "FAIL: timer interrupt set should be a one-cycle pulse"
            severity failure;

        report "=== tb_timer: ALL TESTS PASSED ===" severity note;
        sim_done <= true;
        wait;
    end process p_stimulus;

end architecture sim;
