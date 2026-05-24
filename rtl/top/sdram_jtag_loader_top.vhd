-- =============================================================================
-- Module:      sdram_jtag_loader_top
-- Description: Physical SDRAM ROM loader top using Altera Virtual JTAG
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-23
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-23 - Initial Virtual JTAG to SDRAM loader top
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sdram_jtag_loader_top is
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
end entity sdram_jtag_loader_top;

architecture rtl of sdram_jtag_loader_top is

    signal reset_meta        : std_logic;
    signal reset_sync        : std_logic;
    signal reset             : std_logic;

    signal stream_valid      : std_logic;
    signal stream_data       : std_logic_vector(7 downto 0);
    signal stream_ready      : std_logic;
    signal start_pulse       : std_logic;
    signal finish_pulse      : std_logic;
    signal protocol_error    : std_logic;
    signal loader_busy       : std_logic;
    signal loader_done       : std_logic;
    signal loader_error      : std_logic;
    signal loaded_words      : unsigned(21 downto 0);

    signal sdram_ready       : std_logic;
    signal sdram_cmd_accept  : std_logic;
    signal sdram_cmd_valid   : std_logic;
    signal sdram_cmd_write   : std_logic;
    signal sdram_cmd_addr    : unsigned(21 downto 0);
    signal sdram_write_data  : std_logic_vector(15 downto 0);
    signal sdram_byte_enable : std_logic_vector(1 downto 0);
    signal sdram_read_valid  : std_logic;
    signal sdram_read_data   : std_logic_vector(15 downto 0);
    signal sdram_init_done   : std_logic;
    signal refresh_pulse     : std_logic;

begin

    p_reset_sync: process(clk_50mhz)
    begin
        if rising_edge(clk_50mhz) then
            reset_meta <= not reset_n;
            reset_sync <= reset_meta;
        end if;
    end process p_reset_sync;

    reset <= reset_sync;

    u_jtag_stream: entity work.virtual_jtag_rom_stream
        port map (
            clk             => clk_50mhz,
            reset           => reset,
            stream_valid    => stream_valid,
            stream_data     => stream_data,
            stream_ready    => stream_ready,
            start_pulse     => start_pulse,
            finish_pulse    => finish_pulse,
            protocol_error  => protocol_error,
            loader_busy     => loader_busy,
            loader_done     => loader_done,
            loader_error    => loader_error,
            sdram_init_done => sdram_init_done
        );

    u_loader: entity work.sdram_rom_loader
        generic map (
            G_ADDR_WIDTH => 22
        )
        port map (
            clk               => clk_50mhz,
            reset             => reset,
            start             => start_pulse,
            finish            => finish_pulse,
            stream_valid      => stream_valid,
            stream_data       => stream_data,
            stream_ready      => stream_ready,
            busy              => loader_busy,
            done              => loader_done,
            error             => loader_error,
            loaded_words      => loaded_words,
            sdram_ready       => sdram_ready,
            sdram_cmd_accept  => sdram_cmd_accept,
            sdram_cmd_valid   => sdram_cmd_valid,
            sdram_cmd_write   => sdram_cmd_write,
            sdram_cmd_addr    => sdram_cmd_addr,
            sdram_write_data  => sdram_write_data,
            sdram_byte_enable => sdram_byte_enable
        );

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
            cmd_valid     => sdram_cmd_valid,
            cmd_write     => sdram_cmd_write,
            cmd_addr      => sdram_cmd_addr,
            write_data    => sdram_write_data,
            byte_enable   => sdram_byte_enable,
            ready         => sdram_ready,
            cmd_accept    => sdram_cmd_accept,
            read_valid    => sdram_read_valid,
            read_data     => sdram_read_data,
            init_done     => sdram_init_done,
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

    -- LEDs are active-low on the OMDAZZ board.
    led(0) <= not sdram_init_done;
    led(1) <= not loader_busy;
    led(2) <= not loader_done;
    led(3) <= not (loader_error or protocol_error);

end architecture rtl;
