-- =============================================================================
-- Module:      tb_sdram_controller
-- Description: Self-checking testbench for the minimal SDRAM controller
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-22
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_sdram_controller is
end entity tb_sdram_controller;

architecture sim of tb_sdram_controller is

    constant CLK_PERIOD : time := 20 ns;
    constant MEMORY_WORDS : integer := 2048;

    constant SDRAM_CMD_ACTIVE    : std_logic_vector(3 downto 0) := "0011";
    constant SDRAM_CMD_READ      : std_logic_vector(3 downto 0) := "0101";
    constant SDRAM_CMD_WRITE     : std_logic_vector(3 downto 0) := "0100";
    constant SDRAM_CMD_PRECHARGE : std_logic_vector(3 downto 0) := "0010";
    constant SDRAM_CMD_REFRESH   : std_logic_vector(3 downto 0) := "0001";
    constant SDRAM_CMD_MODE      : std_logic_vector(3 downto 0) := "0000";

    signal clk          : std_logic := '0';
    signal reset        : std_logic := '1';
    signal sim_done     : boolean := false;

    signal cmd_valid    : std_logic := '0';
    signal cmd_write    : std_logic := '0';
    signal cmd_addr     : unsigned(21 downto 0) := (others => '0');
    signal write_data   : std_logic_vector(15 downto 0) := (others => '0');
    signal byte_enable  : std_logic_vector(1 downto 0) := "11";
    signal ready        : std_logic;
    signal cmd_accept   : std_logic;
    signal read_valid   : std_logic;
    signal read_data    : std_logic_vector(15 downto 0);
    signal init_done    : std_logic;
    signal refresh_pulse: std_logic;

    signal sdram_clk    : std_logic;
    signal sdram_cke    : std_logic;
    signal sdram_cs_n   : std_logic;
    signal sdram_ras_n  : std_logic;
    signal sdram_cas_n  : std_logic;
    signal sdram_we_n   : std_logic;
    signal sdram_dqm    : std_logic_vector(1 downto 0);
    signal sdram_ba     : std_logic_vector(1 downto 0);
    signal sdram_addr   : std_logic_vector(11 downto 0);
    signal sdram_dq     : std_logic_vector(15 downto 0);

    signal model_dq_out : std_logic_vector(15 downto 0) := (others => '0');
    signal model_dq_oe  : std_logic := '0';
    signal model_read_pending : std_logic := '0';
    signal model_read_delay   : unsigned(1 downto 0) := (others => '0');
    signal model_read_data    : std_logic_vector(15 downto 0) := (others => '0');
    signal seen_precharge : std_logic := '0';
    signal seen_refresh   : unsigned(3 downto 0) := (others => '0');
    signal seen_mode      : std_logic := '0';

    type ram_t is array (0 to MEMORY_WORDS - 1) of std_logic_vector(15 downto 0);
    type row_array_t is array (0 to 3) of std_logic_vector(11 downto 0);

    signal ram : ram_t := (others => (others => '0'));
    signal active_rows : row_array_t := (others => (others => '0'));

    function word_index(
        row_in  : std_logic_vector(11 downto 0);
        bank_in : std_logic_vector(1 downto 0);
        col_in  : std_logic_vector(7 downto 0))
        return integer is
        variable linear_slv_v : std_logic_vector(21 downto 0);
        variable index_v  : integer;
    begin
        linear_slv_v := row_in & bank_in & col_in;
        index_v := to_integer(unsigned(linear_slv_v));
        return index_v mod MEMORY_WORDS;
    end function word_index;

    procedure issue_write(
        signal cmd_valid_s   : out std_logic;
        signal cmd_write_s   : out std_logic;
        signal cmd_addr_s    : out unsigned(21 downto 0);
        signal write_data_s  : out std_logic_vector(15 downto 0);
        signal byte_enable_s : out std_logic_vector(1 downto 0);
        constant addr_in     : in  natural;
        constant data_in     : in  std_logic_vector(15 downto 0);
        constant be_in       : in  std_logic_vector(1 downto 0)) is
    begin
        cmd_addr_s <= to_unsigned(addr_in, 22);
        write_data_s <= data_in;
        byte_enable_s <= be_in;
        cmd_write_s <= '1';
        cmd_valid_s <= '1';
        wait until rising_edge(clk);
        cmd_valid_s <= '0';
        cmd_write_s <= '0';
    end procedure issue_write;

    procedure issue_read(
        signal cmd_valid_s : out std_logic;
        signal cmd_write_s : out std_logic;
        signal cmd_addr_s  : out unsigned(21 downto 0);
        constant addr_in   : in  natural) is
    begin
        cmd_addr_s <= to_unsigned(addr_in, 22);
        cmd_write_s <= '0';
        cmd_valid_s <= '1';
        wait until rising_edge(clk);
        cmd_valid_s <= '0';
    end procedure issue_read;

begin

    sdram_dq <= model_dq_out when model_dq_oe = '1' else (others => 'Z');

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

    u_dut: entity work.sdram_controller
        generic map (
            G_INIT_WAIT_CYCLES   => 8,
            G_REFRESH_INTERVAL   => 16,
            G_TRP_CYCLES         => 2,
            G_TRCD_CYCLES        => 2,
            G_TRC_CYCLES         => 4,
            G_TWR_CYCLES         => 2,
            G_TMRD_CYCLES        => 2,
            G_CAS_LATENCY_CYCLES => 2
        )
        port map (
            clk         => clk,
            reset       => reset,
            cmd_valid   => cmd_valid,
            cmd_write   => cmd_write,
            cmd_addr    => cmd_addr,
            write_data  => write_data,
            byte_enable => byte_enable,
            ready       => ready,
            cmd_accept  => cmd_accept,
            read_valid  => read_valid,
            read_data   => read_data,
            init_done   => init_done,
            refresh_pulse => refresh_pulse,
            sdram_clk   => sdram_clk,
            sdram_cke   => sdram_cke,
            sdram_cs_n  => sdram_cs_n,
            sdram_ras_n => sdram_ras_n,
            sdram_cas_n => sdram_cas_n,
            sdram_we_n  => sdram_we_n,
            sdram_dqm   => sdram_dqm,
            sdram_ba    => sdram_ba,
            sdram_addr  => sdram_addr,
            sdram_dq    => sdram_dq
        );

    p_sdram_model: process(clk)
        variable command_v : std_logic_vector(3 downto 0);
        variable bank_v    : integer;
        variable index_v   : integer;
        variable data_v    : std_logic_vector(15 downto 0);
    begin
        if rising_edge(clk) then
            command_v := sdram_cs_n & sdram_ras_n & sdram_cas_n & sdram_we_n;
            bank_v := to_integer(unsigned(sdram_ba));
            model_dq_oe <= '0';

            if model_read_pending = '1' then
                if model_read_delay = "00" then
                    model_dq_out <= model_read_data;
                    model_dq_oe <= '1';
                    model_read_pending <= '0';
                else
                    model_read_delay <= model_read_delay - 1;
                end if;
            end if;

            case command_v is
                when SDRAM_CMD_ACTIVE =>
                    active_rows(bank_v) <= sdram_addr;

                when SDRAM_CMD_WRITE =>
                    index_v := word_index(active_rows(bank_v), sdram_ba, sdram_addr(7 downto 0));
                    data_v := ram(index_v);
                    if sdram_dqm(0) = '0' then
                        data_v(7 downto 0) := sdram_dq(7 downto 0);
                    end if;
                    if sdram_dqm(1) = '0' then
                        data_v(15 downto 8) := sdram_dq(15 downto 8);
                    end if;
                    ram(index_v) <= data_v;

                when SDRAM_CMD_READ =>
                    index_v := word_index(active_rows(bank_v), sdram_ba, sdram_addr(7 downto 0));
                    model_read_data <= ram(index_v);
                    model_read_delay <= "00";
                    model_read_pending <= '1';

                when SDRAM_CMD_PRECHARGE =>
                    seen_precharge <= '1';

                when SDRAM_CMD_REFRESH =>
                    if seen_refresh /= x"F" then
                        seen_refresh <= seen_refresh + 1;
                    end if;

                when SDRAM_CMD_MODE =>
                    seen_mode <= '1';

                when others =>
                    null;
            end case;
        end if;
    end process p_sdram_model;

    p_stimulus: process
    begin
        report "=== tb_sdram_controller: Starting simulation ===" severity note;

        reset <= '1';
        wait for CLK_PERIOD * 4;
        reset <= '0';

        wait until init_done = '1';
        wait until rising_edge(clk);
        assert seen_precharge = '1'
            report "FAIL: SDRAM init did not issue precharge"
            severity failure;
        assert seen_refresh >= to_unsigned(2, 4)
            report "FAIL: SDRAM init did not issue refresh commands"
            severity failure;
        assert seen_mode = '1'
            report "FAIL: SDRAM init did not load mode register"
            severity failure;

        wait until ready = '1';
        issue_write(cmd_valid, cmd_write, cmd_addr, write_data, byte_enable,
                    16#0123#, x"CAFE", "11");

        wait until ready = '1';
        issue_read(cmd_valid, cmd_write, cmd_addr, 16#0123#);
        wait until read_valid = '1';
        assert read_data = x"CAFE"
            report "FAIL: SDRAM readback after full-word write is wrong, got " &
                   integer'image(to_integer(unsigned(read_data)))
            severity failure;

        wait until ready = '1';
        issue_write(cmd_valid, cmd_write, cmd_addr, write_data, byte_enable,
                    16#0123#, x"5500", "01");

        wait until ready = '1';
        issue_read(cmd_valid, cmd_write, cmd_addr, 16#0123#);
        wait until read_valid = '1';
        assert read_data = x"CA00"
            report "FAIL: SDRAM byte-enable write did not preserve upper byte, got " &
                   integer'image(to_integer(unsigned(read_data)))
            severity failure;

        wait for CLK_PERIOD * 80;
        assert seen_refresh > to_unsigned(2, 4)
            report "FAIL: SDRAM periodic refresh did not run"
            severity failure;

        report "=== tb_sdram_controller: ALL TESTS PASSED ===" severity note;
        sim_done <= true;
        wait;
    end process p_stimulus;

end architecture sim;
