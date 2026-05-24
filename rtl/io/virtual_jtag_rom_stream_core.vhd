-- =============================================================================
-- Module:      virtual_jtag_rom_stream_core
-- Description: Virtual JTAG byte-stream protocol core with clock-domain crossing
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-23
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-23 - Initial Virtual JTAG stream protocol core
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity virtual_jtag_rom_stream_core is
    port (
        clk              : in  std_logic;
        reset            : in  std_logic;

        stream_valid     : out std_logic;
        stream_data      : out std_logic_vector(7 downto 0);
        stream_ready     : in  std_logic;
        start_pulse      : out std_logic;
        finish_pulse     : out std_logic;
        protocol_error   : out std_logic;

        loader_busy      : in  std_logic;
        loader_done      : in  std_logic;
        loader_error     : in  std_logic;
        sdram_init_done  : in  std_logic;

        vj_tck           : in  std_logic;
        vj_tdi           : in  std_logic;
        vj_ir_in         : in  std_logic_vector(2 downto 0);
        vj_state_cdr     : in  std_logic;
        vj_state_sdr     : in  std_logic;
        vj_state_udr     : in  std_logic;
        vj_tdo           : out std_logic
    );
end entity virtual_jtag_rom_stream_core;

architecture rtl of virtual_jtag_rom_stream_core is

    constant IR_DATA    : std_logic_vector(2 downto 0) := "001";
    constant IR_CONTROL : std_logic_vector(2 downto 0) := "010";
    constant IR_STATUS  : std_logic_vector(2 downto 0) := "011";

    signal dr_shift_reg         : std_logic_vector(7 downto 0);
    signal status_shift_reg     : std_logic_vector(7 downto 0);
    signal byte_data_tck_reg    : std_logic_vector(7 downto 0);
    signal byte_req_tck_reg     : std_logic;
    signal byte_ack_tck_meta    : std_logic;
    signal byte_ack_tck_sync    : std_logic;
    signal start_req_tck_reg    : std_logic;
    signal finish_req_tck_reg   : std_logic;
    signal overflow_tck_reg     : std_logic;
    signal vj_tdo_reg           : std_logic;

    signal stream_ready_tck_meta: std_logic;
    signal stream_ready_tck_sync: std_logic;
    signal busy_tck_meta        : std_logic;
    signal busy_tck_sync        : std_logic;
    signal done_tck_meta        : std_logic;
    signal done_tck_sync        : std_logic;
    signal error_tck_meta       : std_logic;
    signal error_tck_sync       : std_logic;
    signal init_tck_meta        : std_logic;
    signal init_tck_sync        : std_logic;

    signal byte_req_clk_meta    : std_logic;
    signal byte_req_clk_sync    : std_logic;
    signal byte_req_clk_last    : std_logic;
    signal byte_ack_clk_reg     : std_logic;
    signal byte_pending_clk_reg : std_logic;
    signal byte_data_clk_reg    : std_logic_vector(7 downto 0);
    signal stream_valid_reg     : std_logic;
    signal stream_data_reg      : std_logic_vector(7 downto 0);

    signal start_clk_meta       : std_logic;
    signal start_clk_sync       : std_logic;
    signal start_clk_last       : std_logic;
    signal finish_clk_meta      : std_logic;
    signal finish_clk_sync      : std_logic;
    signal finish_clk_last      : std_logic;
    signal start_pulse_reg      : std_logic;
    signal finish_pulse_reg     : std_logic;

    signal overflow_clk_meta    : std_logic;
    signal overflow_clk_sync    : std_logic;

begin

    stream_valid <= stream_valid_reg;
    stream_data <= stream_data_reg;
    start_pulse <= start_pulse_reg;
    finish_pulse <= finish_pulse_reg;
    protocol_error <= overflow_clk_sync;
    vj_tdo <= vj_tdo_reg;

    p_jtag_domain: process(vj_tck, reset)
    begin
        if reset = '1' then
            dr_shift_reg <= (others => '0');
            status_shift_reg <= (others => '0');
            byte_data_tck_reg <= (others => '0');
            byte_req_tck_reg <= '0';
            start_req_tck_reg <= '0';
            finish_req_tck_reg <= '0';
            overflow_tck_reg <= '0';
            vj_tdo_reg <= '0';
            stream_ready_tck_meta <= '0';
            stream_ready_tck_sync <= '0';
            busy_tck_meta <= '0';
            busy_tck_sync <= '0';
            done_tck_meta <= '0';
            done_tck_sync <= '0';
            error_tck_meta <= '0';
            error_tck_sync <= '0';
            init_tck_meta <= '0';
            init_tck_sync <= '0';
            byte_ack_tck_meta <= '0';
            byte_ack_tck_sync <= '0';
        elsif rising_edge(vj_tck) then
            stream_ready_tck_meta <= stream_ready;
            stream_ready_tck_sync <= stream_ready_tck_meta;
            busy_tck_meta <= loader_busy;
            busy_tck_sync <= busy_tck_meta;
            done_tck_meta <= loader_done;
            done_tck_sync <= done_tck_meta;
            error_tck_meta <= loader_error;
            error_tck_sync <= error_tck_meta;
            init_tck_meta <= sdram_init_done;
            init_tck_sync <= init_tck_meta;
            byte_ack_tck_meta <= byte_ack_clk_reg;
            byte_ack_tck_sync <= byte_ack_tck_meta;

            if vj_state_cdr = '1' then
                if vj_ir_in = IR_STATUS then
                    status_shift_reg(0) <= stream_ready_tck_sync;
                    status_shift_reg(1) <= busy_tck_sync;
                    status_shift_reg(2) <= done_tck_sync;
                    status_shift_reg(3) <= error_tck_sync;
                    status_shift_reg(4) <= init_tck_sync;
                    status_shift_reg(5) <= byte_req_tck_reg xor byte_ack_tck_sync;
                    status_shift_reg(6) <= overflow_tck_reg;
                    status_shift_reg(7) <= '1';
                else
                    dr_shift_reg <= (others => '0');
                end if;
            end if;

            if vj_state_sdr = '1' then
                if vj_ir_in = IR_STATUS then
                    vj_tdo_reg <= status_shift_reg(0);
                    status_shift_reg <= '0' & status_shift_reg(7 downto 1);
                else
                    dr_shift_reg <= vj_tdi & dr_shift_reg(7 downto 1);
                    vj_tdo_reg <= '0';
                end if;
            end if;

            if vj_state_udr = '1' then
                if vj_ir_in = IR_DATA then
                    if byte_req_tck_reg = byte_ack_tck_sync then
                        byte_data_tck_reg <= dr_shift_reg;
                        byte_req_tck_reg <= not byte_req_tck_reg;
                    else
                        overflow_tck_reg <= '1';
                    end if;
                elsif vj_ir_in = IR_CONTROL then
                    if dr_shift_reg(0) = '1' then
                        start_req_tck_reg <= not start_req_tck_reg;
                    end if;
                    if dr_shift_reg(1) = '1' then
                        finish_req_tck_reg <= not finish_req_tck_reg;
                    end if;
                    if dr_shift_reg(2) = '1' then
                        overflow_tck_reg <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process p_jtag_domain;

    p_clk_domain: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                byte_req_clk_meta <= '0';
                byte_req_clk_sync <= '0';
                byte_req_clk_last <= '0';
                byte_ack_clk_reg <= '0';
                byte_pending_clk_reg <= '0';
                byte_data_clk_reg <= (others => '0');
                stream_valid_reg <= '0';
                stream_data_reg <= (others => '0');
                start_clk_meta <= '0';
                start_clk_sync <= '0';
                start_clk_last <= '0';
                finish_clk_meta <= '0';
                finish_clk_sync <= '0';
                finish_clk_last <= '0';
                start_pulse_reg <= '0';
                finish_pulse_reg <= '0';
                overflow_clk_meta <= '0';
                overflow_clk_sync <= '0';
            else
                byte_req_clk_meta <= byte_req_tck_reg;
                byte_req_clk_sync <= byte_req_clk_meta;
                start_clk_meta <= start_req_tck_reg;
                start_clk_sync <= start_clk_meta;
                finish_clk_meta <= finish_req_tck_reg;
                finish_clk_sync <= finish_clk_meta;
                overflow_clk_meta <= overflow_tck_reg;
                overflow_clk_sync <= overflow_clk_meta;

                stream_valid_reg <= '0';
                start_pulse_reg <= '0';
                finish_pulse_reg <= '0';

                if byte_req_clk_sync /= byte_req_clk_last then
                    byte_data_clk_reg <= byte_data_tck_reg;
                    byte_pending_clk_reg <= '1';
                    byte_req_clk_last <= byte_req_clk_sync;
                elsif byte_pending_clk_reg = '1' and stream_ready = '1' then
                    stream_data_reg <= byte_data_clk_reg;
                    stream_valid_reg <= '1';
                    byte_pending_clk_reg <= '0';
                    byte_ack_clk_reg <= not byte_ack_clk_reg;
                end if;

                if start_clk_sync /= start_clk_last then
                    start_pulse_reg <= '1';
                    start_clk_last <= start_clk_sync;
                end if;

                if finish_clk_sync /= finish_clk_last then
                    finish_pulse_reg <= '1';
                    finish_clk_last <= finish_clk_sync;
                end if;
            end if;
        end if;
    end process p_clk_domain;

end architecture rtl;
