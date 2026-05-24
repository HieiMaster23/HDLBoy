-- =============================================================================
-- Module:      virtual_jtag_rom_stream
-- Description: Altera Virtual JTAG wrapper for the SDRAM ROM byte stream
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-23
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-23 - Initial sld_virtual_jtag wrapper
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity virtual_jtag_rom_stream is
    port (
        clk             : in  std_logic;
        reset           : in  std_logic;

        stream_valid    : out std_logic;
        stream_data     : out std_logic_vector(7 downto 0);
        stream_ready    : in  std_logic;
        start_pulse     : out std_logic;
        finish_pulse    : out std_logic;
        protocol_error  : out std_logic;

        loader_busy     : in  std_logic;
        loader_done     : in  std_logic;
        loader_error    : in  std_logic;
        sdram_init_done : in  std_logic
    );
end entity virtual_jtag_rom_stream;

architecture rtl of virtual_jtag_rom_stream is

    component sld_virtual_jtag
        generic (
            lpm_hint                : string := "UNUSED";
            lpm_type                : string := "sld_virtual_jtag";
            sld_auto_instance_index : string := "NO";
            sld_instance_index      : natural := 0;
            sld_ir_width            : natural := 3;
            sld_sim_action          : string := "UNUSED";
            sld_sim_n_scan          : natural := 0;
            sld_sim_total_length    : natural := 0
        );
        port (
            ir_in              : out std_logic_vector(2 downto 0);
            ir_out             : in  std_logic_vector(2 downto 0);
            jtag_state_cdr     : out std_logic;
            jtag_state_cir     : out std_logic;
            jtag_state_e1dr    : out std_logic;
            jtag_state_e1ir    : out std_logic;
            jtag_state_e2dr    : out std_logic;
            jtag_state_e2ir    : out std_logic;
            jtag_state_pdr     : out std_logic;
            jtag_state_pir     : out std_logic;
            jtag_state_rti     : out std_logic;
            jtag_state_sdr     : out std_logic;
            jtag_state_sdrs    : out std_logic;
            jtag_state_sir     : out std_logic;
            jtag_state_sirs    : out std_logic;
            jtag_state_tlr     : out std_logic;
            jtag_state_udr     : out std_logic;
            jtag_state_uir     : out std_logic;
            tck                : out std_logic;
            tdi                : out std_logic;
            tdo                : in  std_logic;
            tms                : out std_logic;
            virtual_state_cdr  : out std_logic;
            virtual_state_cir  : out std_logic;
            virtual_state_e1dr : out std_logic;
            virtual_state_e2dr : out std_logic;
            virtual_state_pdr  : out std_logic;
            virtual_state_sdr  : out std_logic;
            virtual_state_udr  : out std_logic;
            virtual_state_uir  : out std_logic
        );
    end component;

    signal vj_ir_in       : std_logic_vector(2 downto 0);
    signal vj_ir_out      : std_logic_vector(2 downto 0);
    signal vj_tck         : std_logic;
    signal vj_tdi         : std_logic;
    signal vj_tdo         : std_logic;
    signal vj_state_cdr   : std_logic;
    signal vj_state_sdr   : std_logic;
    signal vj_state_udr   : std_logic;

    signal unused_jtag_state_cir  : std_logic;
    signal unused_jtag_state_e1dr : std_logic;
    signal unused_jtag_state_e1ir : std_logic;
    signal unused_jtag_state_e2dr : std_logic;
    signal unused_jtag_state_e2ir : std_logic;
    signal unused_jtag_state_pdr  : std_logic;
    signal unused_jtag_state_pir  : std_logic;
    signal unused_jtag_state_rti  : std_logic;
    signal unused_jtag_state_sdrs : std_logic;
    signal unused_jtag_state_sir  : std_logic;
    signal unused_jtag_state_sirs : std_logic;
    signal unused_jtag_state_tlr  : std_logic;
    signal unused_jtag_state_uir  : std_logic;
    signal unused_tms             : std_logic;
    signal unused_virtual_cir     : std_logic;
    signal unused_virtual_e1dr    : std_logic;
    signal unused_virtual_e2dr    : std_logic;
    signal unused_virtual_pdr     : std_logic;
    signal unused_virtual_uir     : std_logic;

begin

    vj_ir_out <= (others => '0');

    u_vjtag: sld_virtual_jtag
        generic map (
            sld_auto_instance_index => "YES",
            sld_instance_index      => 0,
            sld_ir_width            => 3
        )
        port map (
            ir_in              => vj_ir_in,
            ir_out             => vj_ir_out,
            jtag_state_cdr     => open,
            jtag_state_cir     => unused_jtag_state_cir,
            jtag_state_e1dr    => unused_jtag_state_e1dr,
            jtag_state_e1ir    => unused_jtag_state_e1ir,
            jtag_state_e2dr    => unused_jtag_state_e2dr,
            jtag_state_e2ir    => unused_jtag_state_e2ir,
            jtag_state_pdr     => unused_jtag_state_pdr,
            jtag_state_pir     => unused_jtag_state_pir,
            jtag_state_rti     => unused_jtag_state_rti,
            jtag_state_sdr     => open,
            jtag_state_sdrs    => unused_jtag_state_sdrs,
            jtag_state_sir     => unused_jtag_state_sir,
            jtag_state_sirs    => unused_jtag_state_sirs,
            jtag_state_tlr     => unused_jtag_state_tlr,
            jtag_state_udr     => open,
            jtag_state_uir     => unused_jtag_state_uir,
            tck                => vj_tck,
            tdi                => vj_tdi,
            tdo                => vj_tdo,
            tms                => unused_tms,
            virtual_state_cdr  => vj_state_cdr,
            virtual_state_cir  => unused_virtual_cir,
            virtual_state_e1dr => unused_virtual_e1dr,
            virtual_state_e2dr => unused_virtual_e2dr,
            virtual_state_pdr  => unused_virtual_pdr,
            virtual_state_sdr  => vj_state_sdr,
            virtual_state_udr  => vj_state_udr,
            virtual_state_uir  => unused_virtual_uir
        );

    u_core: entity work.virtual_jtag_rom_stream_core
        port map (
            clk             => clk,
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
            sdram_init_done => sdram_init_done,
            vj_tck          => vj_tck,
            vj_tdi          => vj_tdi,
            vj_ir_in        => vj_ir_in,
            vj_state_cdr    => vj_state_cdr,
            vj_state_sdr    => vj_state_sdr,
            vj_state_udr    => vj_state_udr,
            vj_tdo          => vj_tdo
        );

end architecture rtl;
