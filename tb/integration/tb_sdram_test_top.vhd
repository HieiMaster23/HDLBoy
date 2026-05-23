-- =============================================================================
-- Module:      tb_sdram_test_top
-- Description: Integration test for the physical SDRAM bring-up top
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-23
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_sdram_test_top is
end entity tb_sdram_test_top;

architecture sim of tb_sdram_test_top is

    constant CLK_PERIOD : time := 20 ns;
    constant MEMORY_WORDS : integer := 2048;

    constant SDRAM_CMD_ACTIVE    : std_logic_vector(3 downto 0) := "0011";
    constant SDRAM_CMD_READ      : std_logic_vector(3 downto 0) := "0101";
    constant SDRAM_CMD_WRITE     : std_logic_vector(3 downto 0) := "0100";
    constant SDRAM_CMD_PRECHARGE : std_logic_vector(3 downto 0) := "0010";
    constant SDRAM_CMD_REFRESH   : std_logic_vector(3 downto 0) := "0001";

    signal clk_50mhz   : std_logic := '0';
    signal reset_n     : std_logic := '0';
    signal led         : std_logic_vector(3 downto 0);
    signal sdram_clk   : std_logic;
    signal sdram_cke   : std_logic;
    signal sdram_cs_n  : std_logic;
    signal sdram_ras_n : std_logic;
    signal sdram_cas_n : std_logic;
    signal sdram_we_n  : std_logic;
    signal sdram_dqm   : std_logic_vector(1 downto 0);
    signal sdram_ba    : std_logic_vector(1 downto 0);
    signal sdram_addr  : std_logic_vector(11 downto 0);
    signal sdram_dq    : std_logic_vector(15 downto 0);
    signal sim_done    : boolean := false;

    signal model_dq_out : std_logic_vector(15 downto 0) := (others => '0');
    signal model_dq_oe  : std_logic := '0';
    signal model_read_pending : std_logic := '0';
    signal model_read_data    : std_logic_vector(15 downto 0) := (others => '0');
    signal model_hold_count   : unsigned(1 downto 0) := (others => '0');
    signal seen_refresh : std_logic := '0';

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
    begin
        linear_slv_v := row_in & bank_in & col_in;
        return to_integer(unsigned(linear_slv_v)) mod MEMORY_WORDS;
    end function word_index;

begin

    sdram_dq <= model_dq_out when model_dq_oe = '1' else (others => 'Z');

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

    u_dut: entity work.sdram_test_top
        generic map (
            G_INIT_WAIT_CYCLES => 8,
            G_REFRESH_INTERVAL => 16
        )
        port map (
            clk_50mhz   => clk_50mhz,
            reset_n     => reset_n,
            led         => led,
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

    p_sdram_model: process(sdram_clk)
        variable command_v : std_logic_vector(3 downto 0);
        variable bank_v    : integer;
        variable index_v   : integer;
        variable data_v    : std_logic_vector(15 downto 0);
    begin
        if rising_edge(sdram_clk) then
            command_v := sdram_cs_n & sdram_ras_n & sdram_cas_n & sdram_we_n;
            bank_v := to_integer(unsigned(sdram_ba));
            model_dq_oe <= '0';

            if model_hold_count /= "00" then
                model_dq_out <= model_read_data;
                model_dq_oe <= '1';
                model_hold_count <= model_hold_count - 1;
            elsif model_read_pending = '1' then
                model_dq_out <= model_read_data;
                model_dq_oe <= '1';
                model_hold_count <= "01";
                model_read_pending <= '0';
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
                    model_read_pending <= '1';

                when SDRAM_CMD_REFRESH =>
                    seen_refresh <= '1';

                when others =>
                    null;
            end case;
        end if;
    end process p_sdram_model;

    p_stimulus: process
    begin
        report "=== tb_sdram_test_top: Starting simulation ===" severity note;

        reset_n <= '0';
        wait for CLK_PERIOD * 8;
        reset_n <= '1';

        wait for CLK_PERIOD * 2000;

        assert led(0) = '0'
            report "FAIL: SDRAM test top did not report init_done"
            severity failure;
        assert led(1) = '0'
            report "FAIL: SDRAM test top did not report PASS"
            severity failure;
        assert led(2) = '1'
            report "FAIL: SDRAM test top reported FAIL"
            severity failure;
        assert led(3) = '0' and seen_refresh = '1'
            report "FAIL: SDRAM test top did not observe refresh activity"
            severity failure;

        report "=== tb_sdram_test_top: ALL TESTS PASSED ===" severity note;
        sim_done <= true;
        wait;
    end process p_stimulus;

end architecture sim;
