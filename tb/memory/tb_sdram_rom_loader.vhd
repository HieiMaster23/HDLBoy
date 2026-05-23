-- =============================================================================
-- Module:      tb_sdram_rom_loader
-- Description: Self-checking testbench for the SDRAM ROM byte-stream loader
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-23
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_sdram_rom_loader is
end entity tb_sdram_rom_loader;

architecture sim of tb_sdram_rom_loader is

    constant CLK_PERIOD : time := 20 ns;
    constant ADDR_WIDTH : natural := 22;

    signal clk               : std_logic := '0';
    signal reset             : std_logic := '1';
    signal start             : std_logic := '0';
    signal finish            : std_logic := '0';
    signal stream_valid      : std_logic := '0';
    signal stream_data       : std_logic_vector(7 downto 0) := (others => '0');
    signal stream_ready      : std_logic;
    signal busy              : std_logic;
    signal done              : std_logic;
    signal error             : std_logic;
    signal loaded_words      : unsigned(ADDR_WIDTH - 1 downto 0);
    signal sdram_ready       : std_logic := '1';
    signal sdram_cmd_accept  : std_logic := '0';
    signal sdram_cmd_valid   : std_logic;
    signal sdram_cmd_write   : std_logic;
    signal sdram_cmd_addr    : unsigned(ADDR_WIDTH - 1 downto 0);
    signal sdram_write_data  : std_logic_vector(15 downto 0);
    signal sdram_byte_enable : std_logic_vector(1 downto 0);
    signal sim_done          : boolean := false;

    procedure wait_cycles(
        constant count : in natural) is
    begin
        for i in 1 to count loop
            wait until rising_edge(clk);
        end loop;
    end procedure wait_cycles;

    procedure pulse_start(
        signal start_out : out std_logic) is
    begin
        wait until rising_edge(clk);
        start_out <= '1';
        wait until rising_edge(clk);
        start_out <= '0';
    end procedure pulse_start;

    procedure send_byte(
        signal valid_out : out std_logic;
        signal data_out  : out std_logic_vector(7 downto 0);
        constant value_in : in std_logic_vector(7 downto 0)) is
    begin
        while stream_ready /= '1' loop
            wait until rising_edge(clk);
        end loop;

        data_out <= value_in;
        valid_out <= '1';
        wait until rising_edge(clk);
        valid_out <= '0';
        data_out <= (others => '0');
    end procedure send_byte;

    procedure pulse_finish(
        signal finish_out : out std_logic) is
    begin
        wait until rising_edge(clk);
        finish_out <= '1';
        wait until rising_edge(clk);
        finish_out <= '0';
    end procedure pulse_finish;

    procedure expect_write(
        signal accept_out : out std_logic;
        signal ready_out  : out std_logic;
        constant addr_in : in natural;
        constant data_in : in std_logic_vector(15 downto 0);
        constant be_in   : in std_logic_vector(1 downto 0)) is
    begin
        while sdram_cmd_valid /= '1' loop
            wait until rising_edge(clk);
        end loop;

        assert sdram_cmd_write = '1'
            report "FAIL: Loader issued a non-write SDRAM command"
            severity failure;
        assert sdram_cmd_addr = to_unsigned(addr_in, ADDR_WIDTH)
            report "FAIL: Loader SDRAM address mismatch"
            severity failure;
        assert sdram_write_data = data_in
            report "FAIL: Loader SDRAM data mismatch"
            severity failure;
        assert sdram_byte_enable = be_in
            report "FAIL: Loader SDRAM byte-enable mismatch"
            severity failure;

        accept_out <= '1';
        wait until rising_edge(clk);
        accept_out <= '0';

        ready_out <= '0';
        wait_cycles(3);
        ready_out <= '1';
        wait until rising_edge(clk);
    end procedure expect_write;

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

    u_loader: entity work.sdram_rom_loader
        generic map (
            G_ADDR_WIDTH => ADDR_WIDTH
        )
        port map (
            clk               => clk,
            reset             => reset,
            start             => start,
            finish            => finish,
            stream_valid      => stream_valid,
            stream_data       => stream_data,
            stream_ready      => stream_ready,
            busy              => busy,
            done              => done,
            error             => error,
            loaded_words      => loaded_words,
            sdram_ready       => sdram_ready,
            sdram_cmd_accept  => sdram_cmd_accept,
            sdram_cmd_valid   => sdram_cmd_valid,
            sdram_cmd_write   => sdram_cmd_write,
            sdram_cmd_addr    => sdram_cmd_addr,
            sdram_write_data  => sdram_write_data,
            sdram_byte_enable => sdram_byte_enable
        );

    p_stimulus: process
    begin
        report "=== tb_sdram_rom_loader: Starting simulation ===" severity note;

        wait_cycles(4);
        reset <= '0';
        wait_cycles(2);

        pulse_start(start);
        wait for 1 ns;
        assert busy = '1'
            report "FAIL: Loader did not enter busy state after start"
            severity failure;

        send_byte(stream_valid, stream_data, x"01");
        send_byte(stream_valid, stream_data, x"02");
        expect_write(sdram_cmd_accept, sdram_ready, 0, x"0201", "11");

        send_byte(stream_valid, stream_data, x"03");
        send_byte(stream_valid, stream_data, x"04");
        expect_write(sdram_cmd_accept, sdram_ready, 1, x"0403", "11");

        send_byte(stream_valid, stream_data, x"05");
        pulse_finish(finish);
        expect_write(sdram_cmd_accept, sdram_ready, 2, x"0005", "01");

        while done /= '1' loop
            wait until rising_edge(clk);
        end loop;

        assert error = '0'
            report "FAIL: Loader reported an unexpected error"
            severity failure;
        assert loaded_words = to_unsigned(3, ADDR_WIDTH)
            report "FAIL: Loader loaded word count mismatch after odd flush"
            severity failure;

        pulse_start(start);
        send_byte(stream_valid, stream_data, x"AA");
        send_byte(stream_valid, stream_data, x"55");
        expect_write(sdram_cmd_accept, sdram_ready, 0, x"55AA", "11");
        pulse_finish(finish);

        while done /= '1' loop
            wait until rising_edge(clk);
        end loop;

        assert loaded_words = to_unsigned(1, ADDR_WIDTH)
            report "FAIL: Loader did not restart from SDRAM word address zero"
            severity failure;

        report "=== tb_sdram_rom_loader: ALL TESTS PASSED ===" severity note;
        sim_done <= true;
        wait;
    end process p_stimulus;

end architecture sim;
