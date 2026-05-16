-- =============================================================================
-- Module:      tb_vram
-- Description: Self-checking testbench for dual-port VRAM
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-16
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_vram is
end entity tb_vram;

architecture sim of tb_vram is

    constant CLK_PERIOD : time := 20 ns;

    signal clk          : std_logic := '0';
    signal sim_done     : boolean := false;
    signal cpu_we       : std_logic := '0';
    signal cpu_addr     : unsigned(12 downto 0) := (others => '0');
    signal cpu_data_in  : std_logic_vector(7 downto 0) := (others => '0');
    signal cpu_data_out : std_logic_vector(7 downto 0);
    signal ppu_addr     : unsigned(12 downto 0) := (others => '0');
    signal ppu_data_out : std_logic_vector(7 downto 0);

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

    u_dut: entity work.vram
        port map (
            clk          => clk,
            cpu_we       => cpu_we,
            cpu_addr     => cpu_addr,
            cpu_data_in  => cpu_data_in,
            cpu_data_out => cpu_data_out,
            ppu_addr     => ppu_addr,
            ppu_data_out => ppu_data_out
        );

    p_stimulus: process
    begin
        report "=== tb_vram: Starting simulation ===" severity note;

        cpu_addr <= to_unsigned(16#000#, 13);
        ppu_addr <= to_unsigned(16#000#, 13);
        cpu_data_in <= x"3C";
        cpu_we <= '1';
        wait until rising_edge(clk);
        cpu_we <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;
        assert cpu_data_out = x"3C"
            report "FAIL: CPU port did not read back first VRAM write"
            severity failure;
        assert ppu_data_out = x"3C"
            report "FAIL: PPU port did not observe first VRAM write"
            severity failure;

        cpu_addr <= to_unsigned(16#1A5#, 13);
        ppu_addr <= to_unsigned(16#1A5#, 13);
        cpu_data_in <= x"C7";
        cpu_we <= '1';
        wait until rising_edge(clk);
        cpu_we <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;
        assert cpu_data_out = x"C7"
            report "FAIL: CPU port did not read back second VRAM write"
            severity failure;
        assert ppu_data_out = x"C7"
            report "FAIL: PPU port did not observe second VRAM write"
            severity failure;

        report "=== tb_vram: ALL TESTS PASSED ===" severity note;
        sim_done <= true;
        wait;
    end process p_stimulus;

end architecture sim;
