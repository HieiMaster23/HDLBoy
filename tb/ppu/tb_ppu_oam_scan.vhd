-- =============================================================================
-- Module:      tb_ppu_oam_scan
-- Description: Self-checking testbench for the initial OAM scan detector
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-20
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_ppu_oam_scan is
end entity tb_ppu_oam_scan;

architecture sim of tb_ppu_oam_scan is

    constant CLK_PERIOD : time := 20 ns;

    type oam_t is array (0 to 255) of std_logic_vector(7 downto 0);

    signal clk               : std_logic := '0';
    signal reset             : std_logic := '1';
    signal start             : std_logic := '0';
    signal current_line      : unsigned(7 downto 0) := (others => '0');
    signal lcdc              : std_logic_vector(7 downto 0) := x"91";
    signal oam_addr          : unsigned(7 downto 0);
    signal oam_read          : std_logic;
    signal oam_data          : std_logic_vector(7 downto 0);
    signal candidate_count   : unsigned(3 downto 0);
    signal candidate_indices : std_logic_vector(79 downto 0);
    signal busy              : std_logic;
    signal done              : std_logic;
    signal sim_done          : boolean := false;
    signal oam_mem           : oam_t := (others => x"00");

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

    u_dut: entity work.ppu_oam_scan
        port map (
            clk               => clk,
            reset             => reset,
            start             => start,
            current_line      => current_line,
            lcdc              => lcdc,
            oam_addr          => oam_addr,
            oam_read          => oam_read,
            oam_data          => oam_data,
            candidate_count   => candidate_count,
            candidate_indices => candidate_indices,
            busy              => busy,
            done              => done
        );

    p_oam: process(clk)
    begin
        if rising_edge(clk) then
            if oam_read = '1' then
                oam_data <= oam_mem(to_integer(oam_addr));
            else
                oam_data <= x"00";
            end if;
        end if;
    end process p_oam;

    p_stimulus: process
    begin
        report "=== tb_ppu_oam_scan: Starting simulation ===" severity note;

        reset <= '1';
        wait for CLK_PERIOD * 4;
        wait until rising_edge(clk);
        reset <= '0';

        for i in 0 to 11 loop
            oam_mem(i * 4) <= x"10";
        end loop;
        oam_mem(12 * 4) <= x"18";
        current_line <= to_unsigned(0, 8);
        lcdc <= x"93";
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';
        wait until done = '1';
        wait for 1 ns;

        assert candidate_count = to_unsigned(10, 4)
            report "FAIL: OAM scan should cap visible candidates at 10"
            severity failure;
        assert candidate_indices(7 downto 0) = x"00"
            report "FAIL: first candidate should be sprite 0"
            severity failure;
        assert candidate_indices(79 downto 72) = x"09"
            report "FAIL: tenth candidate should be sprite 9"
            severity failure;
        assert busy = '0'
            report "FAIL: OAM scan should clear busy when done"
            severity failure;

        reset <= '1';
        wait until rising_edge(clk);
        oam_mem <= (others => x"00");
        oam_mem(0) <= x"08";
        current_line <= to_unsigned(0, 8);
        lcdc <= x"93";
        reset <= '0';
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';
        wait until done = '1';
        wait for 1 ns;

        assert candidate_count = to_unsigned(0, 4)
            report "FAIL: 8x8 sprite with Y=8 should not cover line 0"
            severity failure;

        reset <= '1';
        wait until rising_edge(clk);
        lcdc <= x"97";
        reset <= '0';
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';
        wait until done = '1';
        wait for 1 ns;

        assert candidate_count = to_unsigned(1, 4)
            report "FAIL: 8x16 sprite with Y=8 should cover line 0"
            severity failure;
        assert candidate_indices(7 downto 0) = x"00"
            report "FAIL: tall sprite candidate should be sprite 0"
            severity failure;

        report "=== tb_ppu_oam_scan: ALL TESTS PASSED ===" severity note;
        sim_done <= true;
        wait;
    end process p_stimulus;

end architecture sim;
