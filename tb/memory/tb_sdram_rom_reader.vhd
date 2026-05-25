-- =============================================================================
-- Module:      tb_sdram_rom_reader
-- Description: Testbench for the SDRAM-backed ROM byte reader
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-25
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_sdram_rom_reader is
end entity tb_sdram_rom_reader;

architecture sim of tb_sdram_rom_reader is

    constant CLK_PERIOD : time := 20 ns;

    signal clk               : std_logic := '0';
    signal reset             : std_logic := '1';
    signal cpu_addr          : std_logic_vector(15 downto 0) := (others => '0');
    signal cpu_read          : std_logic := '0';
    signal rom_data          : std_logic_vector(7 downto 0);
    signal rom_ready         : std_logic;
    signal sdram_ready       : std_logic := '1';
    signal sdram_cmd_accept  : std_logic := '0';
    signal sdram_read_valid  : std_logic := '0';
    signal sdram_read_data   : std_logic_vector(15 downto 0) := (others => '0');
    signal sdram_cmd_valid   : std_logic;
    signal sdram_cmd_write   : std_logic;
    signal sdram_cmd_addr    : unsigned(21 downto 0);
    signal sdram_write_data  : std_logic_vector(15 downto 0);
    signal sdram_byte_enable : std_logic_vector(1 downto 0);
    signal sim_done          : boolean := false;

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

    u_dut: entity work.sdram_rom_reader
        port map (
            clk               => clk,
            reset             => reset,
            cpu_addr          => cpu_addr,
            cpu_read          => cpu_read,
            rom_data          => rom_data,
            rom_ready         => rom_ready,
            sdram_ready       => sdram_ready,
            sdram_cmd_accept  => sdram_cmd_accept,
            sdram_read_valid  => sdram_read_valid,
            sdram_read_data   => sdram_read_data,
            sdram_cmd_valid   => sdram_cmd_valid,
            sdram_cmd_write   => sdram_cmd_write,
            sdram_cmd_addr    => sdram_cmd_addr,
            sdram_write_data  => sdram_write_data,
            sdram_byte_enable => sdram_byte_enable
        );

    p_stimulus: process
        procedure wait_clk(count_in : in natural) is
        begin
            for i in 1 to count_in loop
                wait until rising_edge(clk);
                wait for 1 ns;
            end loop;
        end procedure wait_clk;

        procedure start_read(addr_in : in std_logic_vector(15 downto 0)) is
        begin
            cpu_addr <= addr_in;
            cpu_read <= '1';
            wait for 1 ns;
        end procedure start_read;

        procedure complete_sdram_read(word_in : in std_logic_vector(15 downto 0)) is
            variable command_seen_v : boolean;
        begin
            command_seen_v := false;
            for i in 0 to 20 loop
                if sdram_cmd_valid = '1' then
                    command_seen_v := true;
                    exit;
                end if;
                wait until rising_edge(clk);
                wait for 1 ns;
            end loop;
            assert command_seen_v
                report "FAIL: SDRAM command was not issued for ROM read"
                severity failure;

            sdram_cmd_accept <= '1';
            wait until rising_edge(clk);
            wait for 1 ns;
            sdram_cmd_accept <= '0';

            wait_clk(3);
            sdram_read_data <= word_in;
            sdram_read_valid <= '1';
            wait until rising_edge(clk);
            wait for 1 ns;
            sdram_read_valid <= '0';
        end procedure complete_sdram_read;
    begin
        report "=== tb_sdram_rom_reader: Starting simulation ===" severity note;

        reset <= '1';
        wait_clk(4);
        reset <= '0';
        wait_clk(1);

        start_read(x"0000");
        assert rom_ready = '0'
            report "FAIL: first uncached read should not be ready immediately"
            severity failure;
        complete_sdram_read(x"1234");
        wait for 1 ns;
        assert rom_ready = '1' and rom_data = x"34"
            report "FAIL: even byte should select SDRAM word low byte"
            severity failure;
        assert sdram_cmd_write = '0'
            report "FAIL: ROM reader must issue read commands only"
            severity failure;
        assert sdram_cmd_addr = to_unsigned(0, 22)
            report "FAIL: byte address 0x0000 should map to SDRAM word 0"
            severity failure;
        cpu_addr <= x"0001";
        wait for 1 ns;
        assert rom_ready = '0'
            report "FAIL: changing address while read stays high must drop stale ready"
            severity failure;
        complete_sdram_read(x"ABCD");
        wait for 1 ns;
        assert rom_ready = '1' and rom_data = x"AB"
            report "FAIL: back-to-back address change should return the new byte"
            severity failure;
        cpu_read <= '0';
        wait_clk(1);

        start_read(x"7FFE");
        complete_sdram_read(x"5AA5");
        wait for 1 ns;
        assert rom_ready = '1' and rom_data = x"A5"
            report "FAIL: 0x7FFE should read the low byte of SDRAM word 0x3FFF"
            severity failure;
        assert sdram_cmd_addr = to_unsigned(16#3FFF#, 22)
            report "FAIL: 0x7FFE should map to SDRAM word 0x3FFF"
            severity failure;
        cpu_read <= '0';
        wait_clk(1);

        start_read(x"7FFE");
        wait_clk(1);
        assert rom_ready = '1' and rom_data = x"A5"
            report "FAIL: repeated ROM read should be served from the one-byte cache"
            severity failure;
        cpu_read <= '0';
        wait_clk(1);

        sdram_ready <= '0';
        start_read(x"0002");
        wait_clk(3);
        assert sdram_cmd_valid = '0' and rom_ready = '0'
            report "FAIL: reader should wait for SDRAM ready before issuing a command"
            severity failure;
        sdram_ready <= '1';
        complete_sdram_read(x"CAFE");
        wait for 1 ns;
        assert rom_ready = '1' and rom_data = x"FE"
            report "FAIL: pending request should complete after SDRAM becomes ready"
            severity failure;
        cpu_read <= '0';
        wait_clk(1);

        start_read(x"8000");
        wait_clk(3);
        assert sdram_cmd_valid = '0' and rom_ready = '0'
            report "FAIL: addresses above 0x7FFF are outside ROM reader scope"
            severity failure;
        cpu_read <= '0';

        report "=== tb_sdram_rom_reader: ALL TESTS PASSED ===" severity note;
        sim_done <= true;
        wait;
    end process p_stimulus;

end architecture sim;
