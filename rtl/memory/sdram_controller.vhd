-- =============================================================================
-- Module:      sdram_controller
-- Description: Minimal 64 Mbit x16 SDRAM controller for ROM-loading bring-up
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-22
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-22 - Initial single-word init/read/write/refresh controller
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sdram_controller is
    generic (
        G_INIT_WAIT_CYCLES      : natural := 10000;
        G_REFRESH_INTERVAL      : natural := 390;
        G_TRP_CYCLES            : natural := 2;
        G_TRCD_CYCLES           : natural := 2;
        G_TRC_CYCLES            : natural := 4;
        G_TWR_CYCLES            : natural := 2;
        G_TMRD_CYCLES           : natural := 2;
        G_CAS_LATENCY_CYCLES    : natural := 2
    );
    port (
        clk          : in    std_logic;
        reset        : in    std_logic;

        cmd_valid    : in    std_logic;
        cmd_write    : in    std_logic;
        cmd_addr     : in    unsigned(21 downto 0);
        write_data   : in    std_logic_vector(15 downto 0);
        byte_enable  : in    std_logic_vector(1 downto 0);
        ready        : out   std_logic;
        cmd_accept   : out   std_logic;
        read_valid   : out   std_logic;
        read_data    : out   std_logic_vector(15 downto 0);
        init_done    : out   std_logic;
        refresh_pulse: out   std_logic;

        sdram_clk    : out   std_logic;
        sdram_cke    : out   std_logic;
        sdram_cs_n   : out   std_logic;
        sdram_ras_n  : out   std_logic;
        sdram_cas_n  : out   std_logic;
        sdram_we_n   : out   std_logic;
        sdram_dqm    : out   std_logic_vector(1 downto 0);
        sdram_ba     : out   std_logic_vector(1 downto 0);
        sdram_addr   : out   std_logic_vector(11 downto 0);
        sdram_dq     : inout std_logic_vector(15 downto 0)
    );
end entity sdram_controller;

architecture rtl of sdram_controller is

    type state_t is (
        S_RESET_WAIT,
        S_INIT_PRECHARGE,
        S_INIT_REFRESH_1,
        S_INIT_REFRESH_2,
        S_INIT_MODE,
        S_IDLE,
        S_REFRESH,
        S_ACTIVATE,
        S_READ_CMD,
        S_READ_CAPTURE,
        S_WRITE_CMD,
        S_PRECHARGE
    );

    constant SDRAM_CMD_NOP       : std_logic_vector(3 downto 0) := "0111";
    constant SDRAM_CMD_ACTIVE    : std_logic_vector(3 downto 0) := "0011";
    constant SDRAM_CMD_READ      : std_logic_vector(3 downto 0) := "0101";
    constant SDRAM_CMD_WRITE     : std_logic_vector(3 downto 0) := "0100";
    constant SDRAM_CMD_PRECHARGE : std_logic_vector(3 downto 0) := "0010";
    constant SDRAM_CMD_REFRESH   : std_logic_vector(3 downto 0) := "0001";
    constant SDRAM_CMD_MODE      : std_logic_vector(3 downto 0) := "0000";

    -- Burst length 1, sequential burst, CAS latency 2, standard operation.
    constant MODE_REGISTER : std_logic_vector(11 downto 0) := "000000100000";

    signal state_reg       : state_t;
    signal delay_reg       : natural range 0 to 65535;
    signal pending_write_reg : std_logic;
    signal pending_addr_reg  : unsigned(21 downto 0);
    signal pending_data_reg  : std_logic_vector(15 downto 0);
    signal pending_be_reg    : std_logic_vector(1 downto 0);
    signal refresh_count_reg : natural range 0 to 65535;
    signal refresh_pending_reg : std_logic;
    signal command_reg      : std_logic_vector(3 downto 0);
    signal addr_reg         : std_logic_vector(11 downto 0);
    signal ba_reg           : std_logic_vector(1 downto 0);
    signal dqm_reg          : std_logic_vector(1 downto 0);
    signal dq_out_reg       : std_logic_vector(15 downto 0);
    signal dq_oe_reg        : std_logic;
    signal cmd_accept_reg   : std_logic;
    signal read_valid_reg   : std_logic;
    signal read_data_reg    : std_logic_vector(15 downto 0);
    signal init_done_reg    : std_logic;
    signal refresh_pulse_reg: std_logic;

    function timer_done(value_in : natural) return boolean is
    begin
        return value_in = 0;
    end function timer_done;

begin

    -- The external SDRAM samples on its rising edge. Driving an inverted clock
    -- gives the registered command/address/data outputs about half a cycle to
    -- settle before the memory captures them during the initial 50 MHz bring-up.
    sdram_clk <= not clk;
    sdram_cke <= '1';
    sdram_cs_n <= command_reg(3);
    sdram_ras_n <= command_reg(2);
    sdram_cas_n <= command_reg(1);
    sdram_we_n <= command_reg(0);
    sdram_addr <= addr_reg;
    sdram_ba <= ba_reg;
    sdram_dqm <= dqm_reg;
    sdram_dq <= dq_out_reg when dq_oe_reg = '1' else (others => 'Z');

    ready <= '1' when state_reg = S_IDLE and refresh_pending_reg = '0' and init_done_reg = '1' else '0';
    cmd_accept <= cmd_accept_reg;
    read_valid <= read_valid_reg;
    read_data <= read_data_reg;
    init_done <= init_done_reg;
    refresh_pulse <= refresh_pulse_reg;

    p_controller: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state_reg <= S_RESET_WAIT;
                delay_reg <= G_INIT_WAIT_CYCLES;
                pending_write_reg <= '0';
                pending_addr_reg <= (others => '0');
                pending_data_reg <= (others => '0');
                pending_be_reg <= "11";
                refresh_count_reg <= G_REFRESH_INTERVAL;
                refresh_pending_reg <= '0';
                command_reg <= SDRAM_CMD_NOP;
                addr_reg <= (others => '0');
                ba_reg <= (others => '0');
                dqm_reg <= "00";
                dq_out_reg <= (others => '0');
                dq_oe_reg <= '0';
                cmd_accept_reg <= '0';
                read_valid_reg <= '0';
                read_data_reg <= (others => '0');
                init_done_reg <= '0';
                refresh_pulse_reg <= '0';
            else
                command_reg <= SDRAM_CMD_NOP;
                addr_reg <= (others => '0');
                ba_reg <= (others => '0');
                dqm_reg <= "00";
                dq_oe_reg <= '0';
                cmd_accept_reg <= '0';
                read_valid_reg <= '0';
                refresh_pulse_reg <= '0';

                if init_done_reg = '1' then
                    if refresh_count_reg = 0 then
                        refresh_pending_reg <= '1';
                        refresh_count_reg <= G_REFRESH_INTERVAL;
                    else
                        refresh_count_reg <= refresh_count_reg - 1;
                    end if;
                end if;

                case state_reg is
                    when S_RESET_WAIT =>
                        if delay_reg = 0 then
                            command_reg <= SDRAM_CMD_PRECHARGE;
                            addr_reg(10) <= '1';
                            delay_reg <= G_TRP_CYCLES - 1;
                            state_reg <= S_INIT_PRECHARGE;
                        else
                            delay_reg <= delay_reg - 1;
                        end if;

                    when S_INIT_PRECHARGE =>
                        if timer_done(delay_reg) then
                            command_reg <= SDRAM_CMD_REFRESH;
                            delay_reg <= G_TRC_CYCLES - 1;
                            state_reg <= S_INIT_REFRESH_1;
                        else
                            delay_reg <= delay_reg - 1;
                        end if;

                    when S_INIT_REFRESH_1 =>
                        if timer_done(delay_reg) then
                            command_reg <= SDRAM_CMD_REFRESH;
                            delay_reg <= G_TRC_CYCLES - 1;
                            state_reg <= S_INIT_REFRESH_2;
                        else
                            delay_reg <= delay_reg - 1;
                        end if;

                    when S_INIT_REFRESH_2 =>
                        if timer_done(delay_reg) then
                            command_reg <= SDRAM_CMD_MODE;
                            addr_reg <= MODE_REGISTER;
                            delay_reg <= G_TMRD_CYCLES - 1;
                            state_reg <= S_INIT_MODE;
                        else
                            delay_reg <= delay_reg - 1;
                        end if;

                    when S_INIT_MODE =>
                        if timer_done(delay_reg) then
                            init_done_reg <= '1';
                            state_reg <= S_IDLE;
                        else
                            delay_reg <= delay_reg - 1;
                        end if;

                    when S_IDLE =>
                        if refresh_pending_reg = '1' then
                            command_reg <= SDRAM_CMD_REFRESH;
                            refresh_pending_reg <= '0';
                            refresh_pulse_reg <= '1';
                            delay_reg <= G_TRC_CYCLES - 1;
                            state_reg <= S_REFRESH;
                        elsif cmd_valid = '1' then
                            pending_write_reg <= cmd_write;
                            pending_addr_reg <= cmd_addr;
                            pending_data_reg <= write_data;
                            pending_be_reg <= byte_enable;
                            cmd_accept_reg <= '1';
                            command_reg <= SDRAM_CMD_ACTIVE;
                            ba_reg <= std_logic_vector(cmd_addr(9 downto 8));
                            addr_reg <= std_logic_vector(cmd_addr(21 downto 10));
                            delay_reg <= G_TRCD_CYCLES - 1;
                            state_reg <= S_ACTIVATE;
                        end if;

                    when S_REFRESH =>
                        if timer_done(delay_reg) then
                            state_reg <= S_IDLE;
                        else
                            delay_reg <= delay_reg - 1;
                        end if;

                    when S_ACTIVATE =>
                        if timer_done(delay_reg) then
                            ba_reg <= std_logic_vector(pending_addr_reg(9 downto 8));
                            addr_reg(7 downto 0) <= std_logic_vector(pending_addr_reg(7 downto 0));
                            addr_reg(10) <= '0';
                            dqm_reg <= not pending_be_reg;

                            if pending_write_reg = '1' then
                                command_reg <= SDRAM_CMD_WRITE;
                                dq_out_reg <= pending_data_reg;
                                dq_oe_reg <= '1';
                                delay_reg <= G_TWR_CYCLES - 1;
                                state_reg <= S_WRITE_CMD;
                            else
                                command_reg <= SDRAM_CMD_READ;
                                delay_reg <= G_CAS_LATENCY_CYCLES - 1;
                                state_reg <= S_READ_CMD;
                            end if;
                        else
                            delay_reg <= delay_reg - 1;
                        end if;

                    when S_READ_CMD =>
                        if timer_done(delay_reg) then
                            state_reg <= S_READ_CAPTURE;
                        else
                            delay_reg <= delay_reg - 1;
                        end if;

                    when S_READ_CAPTURE =>
                        read_data_reg <= sdram_dq;
                        read_valid_reg <= '1';
                        command_reg <= SDRAM_CMD_PRECHARGE;
                        ba_reg <= std_logic_vector(pending_addr_reg(9 downto 8));
                        addr_reg(10) <= '1';
                        delay_reg <= G_TRP_CYCLES - 1;
                        state_reg <= S_PRECHARGE;

                    when S_WRITE_CMD =>
                        if timer_done(delay_reg) then
                            command_reg <= SDRAM_CMD_PRECHARGE;
                            ba_reg <= std_logic_vector(pending_addr_reg(9 downto 8));
                            addr_reg(10) <= '1';
                            delay_reg <= G_TRP_CYCLES - 1;
                            state_reg <= S_PRECHARGE;
                        else
                            dq_out_reg <= pending_data_reg;
                            dq_oe_reg <= '1';
                            delay_reg <= delay_reg - 1;
                        end if;

                    when S_PRECHARGE =>
                        if timer_done(delay_reg) then
                            state_reg <= S_IDLE;
                        else
                            delay_reg <= delay_reg - 1;
                        end if;
                end case;
            end if;
        end if;
    end process p_controller;

end architecture rtl;
