-- =============================================================================
-- Module:      tb_registers
-- Description: Testbench for LR35902 register file
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-11
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gb_types_pkg.all;

entity tb_registers is
end entity tb_registers;

architecture sim of tb_registers is

    constant CLK_PERIOD : time := 20 ns;

    signal clk : std_logic := '0';
    signal reset : std_logic := '1';
    signal sim_done : boolean := false;

    signal read_sel_a : std_logic_vector(2 downto 0) := CPU_REG_A;
    signal read_sel_b : std_logic_vector(2 downto 0) := CPU_REG_B;
    signal read_data_a : std_logic_vector(7 downto 0);
    signal read_data_b : std_logic_vector(7 downto 0);
    signal write_enable : std_logic := '0';
    signal write_sel : std_logic_vector(2 downto 0) := CPU_REG_A;
    signal write_data : std_logic_vector(7 downto 0) := x"00";
    signal pair_write_enable : std_logic := '0';
    signal pair_write_sel : std_logic_vector(1 downto 0) := CPU_PAIR_HL;
    signal pair_write_data : std_logic_vector(15 downto 0) := x"0000";
    signal flags_write_enable : std_logic := '0';
    signal flags_in : std_logic_vector(3 downto 0) := "0000";
    signal pc_write_enable : std_logic := '0';
    signal pc_in : std_logic_vector(15 downto 0) := x"0000";
    signal pc_out : std_logic_vector(15 downto 0);
    signal sp_write_enable : std_logic := '0';
    signal sp_in : std_logic_vector(15 downto 0) := x"0000";
    signal sp_out : std_logic_vector(15 downto 0);
    signal a_out : std_logic_vector(7 downto 0);
    signal f_out : std_logic_vector(7 downto 0);
    signal b_out : std_logic_vector(7 downto 0);
    signal c_out : std_logic_vector(7 downto 0);
    signal d_out : std_logic_vector(7 downto 0);
    signal e_out : std_logic_vector(7 downto 0);
    signal h_out : std_logic_vector(7 downto 0);
    signal l_out : std_logic_vector(7 downto 0);
    signal hl_out : std_logic_vector(15 downto 0);
    signal flags_out : std_logic_vector(3 downto 0);

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

    u_dut: entity work.registers
        port map (
            clk => clk,
            reset => reset,
            read_sel_a => read_sel_a,
            read_sel_b => read_sel_b,
            read_data_a => read_data_a,
            read_data_b => read_data_b,
            write_enable => write_enable,
            write_sel => write_sel,
            write_data => write_data,
            pair_write_enable => pair_write_enable,
            pair_write_sel => pair_write_sel,
            pair_write_data => pair_write_data,
            flags_write_enable => flags_write_enable,
            flags_in => flags_in,
            pc_write_enable => pc_write_enable,
            pc_in => pc_in,
            pc_out => pc_out,
            sp_write_enable => sp_write_enable,
            sp_in => sp_in,
            sp_out => sp_out,
            a_out => a_out,
            f_out => f_out,
            b_out => b_out,
            c_out => c_out,
            d_out => d_out,
            e_out => e_out,
            h_out => h_out,
            l_out => l_out,
            hl_out => hl_out,
            flags_out => flags_out
        );

    p_stimulus: process
    begin
        report "=== tb_registers: Starting simulation ===" severity note;

        wait for CLK_PERIOD * 2;
        reset <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert pc_out = x"0000" and sp_out = x"FFFE"
            report "FAIL: reset PC/SP values are incorrect"
            severity failure;

        write_enable <= '1';
        write_sel <= CPU_REG_A;
        write_data <= x"42";
        wait until rising_edge(clk);
        write_enable <= '0';
        wait for 1 ns;
        assert a_out = x"42"
            report "FAIL: A register write failed"
            severity failure;

        pair_write_enable <= '1';
        pair_write_sel <= CPU_PAIR_HL;
        pair_write_data <= x"C000";
        wait until rising_edge(clk);
        pair_write_enable <= '0';
        wait for 1 ns;
        assert h_out = x"C0" and l_out = x"00" and hl_out = x"C000"
            report "FAIL: HL pair write failed"
            severity failure;

        flags_write_enable <= '1';
        flags_in <= "1011";
        wait until rising_edge(clk);
        flags_write_enable <= '0';
        wait for 1 ns;
        assert f_out = x"B0" and flags_out = "1011"
            report "FAIL: flags write must update only F[7:4]"
            severity failure;

        pc_write_enable <= '1';
        pc_in <= x"1234";
        sp_write_enable <= '1';
        sp_in <= x"ABCD";
        wait until rising_edge(clk);
        pc_write_enable <= '0';
        sp_write_enable <= '0';
        wait for 1 ns;
        assert pc_out = x"1234" and sp_out = x"ABCD"
            report "FAIL: PC/SP write failed"
            severity failure;

        read_sel_a <= CPU_REG_A;
        read_sel_b <= CPU_REG_H;
        wait for 1 ns;
        assert read_data_a = x"42" and read_data_b = x"C0"
            report "FAIL: combinational register read failed"
            severity failure;

        report "=== tb_registers: ALL TESTS PASSED ===" severity note;
        sim_done <= true;
        wait;
    end process p_stimulus;

end architecture sim;
