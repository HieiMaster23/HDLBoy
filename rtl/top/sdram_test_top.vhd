-- =============================================================================
-- Module:      sdram_test_top
-- Description: Physical SDRAM bring-up top with deterministic read/write checks
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-23
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-23 - Initial SDRAM hardware checker top
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sdram_test_top is
    generic (
        G_INIT_WAIT_CYCLES : natural := 10000;
        G_REFRESH_INTERVAL : natural := 390
    );
    port (
        clk_50mhz   : in    std_logic;
        reset_n     : in    std_logic;

        led         : out   std_logic_vector(3 downto 0);

        sdram_clk   : out   std_logic;
        sdram_cke   : out   std_logic;
        sdram_cs_n  : out   std_logic;
        sdram_ras_n : out   std_logic;
        sdram_cas_n : out   std_logic;
        sdram_we_n  : out   std_logic;
        sdram_dqm   : out   std_logic_vector(1 downto 0);
        sdram_ba    : out   std_logic_vector(1 downto 0);
        sdram_addr  : out   std_logic_vector(11 downto 0);
        sdram_dq    : inout std_logic_vector(15 downto 0)
    );
end entity sdram_test_top;

architecture rtl of sdram_test_top is

    type state_t is (
        S_WAIT_INIT,
        S_WRITE_0_REQ,
        S_WRITE_0_WAIT,
        S_WRITE_1_REQ,
        S_WRITE_1_WAIT,
        S_WRITE_BYTE_BASE_REQ,
        S_WRITE_BYTE_BASE_WAIT,
        S_WRITE_BYTE_LOW_REQ,
        S_WRITE_BYTE_LOW_WAIT,
        S_READ_0_REQ,
        S_READ_0_WAIT,
        S_READ_1_REQ,
        S_READ_1_WAIT,
        S_READ_BYTE_REQ,
        S_READ_BYTE_WAIT,
        S_PASS,
        S_FAIL
    );

    constant ADDR_0    : unsigned(21 downto 0) := to_unsigned(16#000123#, 22);
    constant ADDR_1    : unsigned(21 downto 0) := to_unsigned(16#000456#, 22);
    constant ADDR_BYTE : unsigned(21 downto 0) := to_unsigned(16#000789#, 22);

    signal reset_meta       : std_logic;
    signal reset_sync       : std_logic;
    signal reset            : std_logic;
    signal state_reg        : state_t;
    signal cmd_valid_reg    : std_logic;
    signal cmd_write_reg    : std_logic;
    signal cmd_addr_reg     : unsigned(21 downto 0);
    signal write_data_reg   : std_logic_vector(15 downto 0);
    signal byte_enable_reg  : std_logic_vector(1 downto 0);
    signal ready            : std_logic;
    signal cmd_accept       : std_logic;
    signal read_valid       : std_logic;
    signal read_data        : std_logic_vector(15 downto 0);
    signal init_done        : std_logic;
    signal refresh_pulse    : std_logic;
    signal refresh_seen_reg : std_logic;

begin

    p_reset_sync: process(clk_50mhz)
    begin
        if rising_edge(clk_50mhz) then
            reset_meta <= not reset_n;
            reset_sync <= reset_meta;
        end if;
    end process p_reset_sync;

    reset <= reset_sync;

    u_sdram: entity work.sdram_controller
        generic map (
            G_INIT_WAIT_CYCLES   => G_INIT_WAIT_CYCLES,
            G_REFRESH_INTERVAL   => G_REFRESH_INTERVAL,
            G_TRP_CYCLES         => 2,
            G_TRCD_CYCLES        => 2,
            G_TRC_CYCLES         => 4,
            G_TWR_CYCLES         => 2,
            G_TMRD_CYCLES        => 2,
            G_CAS_LATENCY_CYCLES => 2
        )
        port map (
            clk           => clk_50mhz,
            reset         => reset,
            cmd_valid     => cmd_valid_reg,
            cmd_write     => cmd_write_reg,
            cmd_addr      => cmd_addr_reg,
            write_data    => write_data_reg,
            byte_enable   => byte_enable_reg,
            ready         => ready,
            cmd_accept    => cmd_accept,
            read_valid    => read_valid,
            read_data     => read_data,
            init_done     => init_done,
            refresh_pulse => refresh_pulse,
            sdram_clk     => sdram_clk,
            sdram_cke     => sdram_cke,
            sdram_cs_n    => sdram_cs_n,
            sdram_ras_n   => sdram_ras_n,
            sdram_cas_n   => sdram_cas_n,
            sdram_we_n    => sdram_we_n,
            sdram_dqm     => sdram_dqm,
            sdram_ba      => sdram_ba,
            sdram_addr    => sdram_addr,
            sdram_dq      => sdram_dq
        );

    p_checker: process(clk_50mhz)
    begin
        if rising_edge(clk_50mhz) then
            if reset = '1' then
                state_reg <= S_WAIT_INIT;
                cmd_valid_reg <= '0';
                cmd_write_reg <= '0';
                cmd_addr_reg <= (others => '0');
                write_data_reg <= (others => '0');
                byte_enable_reg <= "11";
                refresh_seen_reg <= '0';
            else
                cmd_valid_reg <= '0';

                if refresh_pulse = '1' then
                    refresh_seen_reg <= '1';
                end if;

                case state_reg is
                    when S_WAIT_INIT =>
                        if init_done = '1' and ready = '1' then
                            state_reg <= S_WRITE_0_REQ;
                        end if;

                    when S_WRITE_0_REQ =>
                        cmd_valid_reg <= '1';
                        cmd_write_reg <= '1';
                        cmd_addr_reg <= ADDR_0;
                        write_data_reg <= x"CAFE";
                        byte_enable_reg <= "11";
                        if cmd_accept = '1' then
                            state_reg <= S_WRITE_0_WAIT;
                        end if;

                    when S_WRITE_0_WAIT =>
                        if ready = '1' then
                            state_reg <= S_WRITE_1_REQ;
                        end if;

                    when S_WRITE_1_REQ =>
                        cmd_valid_reg <= '1';
                        cmd_write_reg <= '1';
                        cmd_addr_reg <= ADDR_1;
                        write_data_reg <= x"5AA5";
                        byte_enable_reg <= "11";
                        if cmd_accept = '1' then
                            state_reg <= S_WRITE_1_WAIT;
                        end if;

                    when S_WRITE_1_WAIT =>
                        if ready = '1' then
                            state_reg <= S_WRITE_BYTE_BASE_REQ;
                        end if;

                    when S_WRITE_BYTE_BASE_REQ =>
                        cmd_valid_reg <= '1';
                        cmd_write_reg <= '1';
                        cmd_addr_reg <= ADDR_BYTE;
                        write_data_reg <= x"1234";
                        byte_enable_reg <= "11";
                        if cmd_accept = '1' then
                            state_reg <= S_WRITE_BYTE_BASE_WAIT;
                        end if;

                    when S_WRITE_BYTE_BASE_WAIT =>
                        if ready = '1' then
                            state_reg <= S_WRITE_BYTE_LOW_REQ;
                        end if;

                    when S_WRITE_BYTE_LOW_REQ =>
                        cmd_valid_reg <= '1';
                        cmd_write_reg <= '1';
                        cmd_addr_reg <= ADDR_BYTE;
                        write_data_reg <= x"00F0";
                        byte_enable_reg <= "01";
                        if cmd_accept = '1' then
                            state_reg <= S_WRITE_BYTE_LOW_WAIT;
                        end if;

                    when S_WRITE_BYTE_LOW_WAIT =>
                        if ready = '1' then
                            state_reg <= S_READ_0_REQ;
                        end if;

                    when S_READ_0_REQ =>
                        cmd_valid_reg <= '1';
                        cmd_write_reg <= '0';
                        cmd_addr_reg <= ADDR_0;
                        byte_enable_reg <= "11";
                        if cmd_accept = '1' then
                            state_reg <= S_READ_0_WAIT;
                        end if;

                    when S_READ_0_WAIT =>
                        if read_valid = '1' then
                            if read_data = x"CAFE" then
                                state_reg <= S_READ_1_REQ;
                            else
                                state_reg <= S_FAIL;
                            end if;
                        end if;

                    when S_READ_1_REQ =>
                        cmd_valid_reg <= '1';
                        cmd_write_reg <= '0';
                        cmd_addr_reg <= ADDR_1;
                        byte_enable_reg <= "11";
                        if cmd_accept = '1' then
                            state_reg <= S_READ_1_WAIT;
                        end if;

                    when S_READ_1_WAIT =>
                        if read_valid = '1' then
                            if read_data = x"5AA5" then
                                state_reg <= S_READ_BYTE_REQ;
                            else
                                state_reg <= S_FAIL;
                            end if;
                        end if;

                    when S_READ_BYTE_REQ =>
                        cmd_valid_reg <= '1';
                        cmd_write_reg <= '0';
                        cmd_addr_reg <= ADDR_BYTE;
                        byte_enable_reg <= "11";
                        if cmd_accept = '1' then
                            state_reg <= S_READ_BYTE_WAIT;
                        end if;

                    when S_READ_BYTE_WAIT =>
                        if read_valid = '1' then
                            if read_data = x"12F0" then
                                state_reg <= S_PASS;
                            else
                                state_reg <= S_FAIL;
                            end if;
                        end if;

                    when S_PASS =>
                        null;

                    when S_FAIL =>
                        null;
                end case;
            end if;
        end if;
    end process p_checker;

    -- Board LEDs are active-low on the current pinout.
    led(0) <= not init_done;
    led(1) <= '0' when state_reg = S_PASS else '1';
    led(2) <= '0' when state_reg = S_FAIL else '1';
    led(3) <= not refresh_seen_reg;

end architecture rtl;
