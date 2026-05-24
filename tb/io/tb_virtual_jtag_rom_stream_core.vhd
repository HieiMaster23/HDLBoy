-- =============================================================================
-- Module:      tb_virtual_jtag_rom_stream_core
-- Description: Self-checking testbench for the Virtual JTAG ROM stream core
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-23
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_virtual_jtag_rom_stream_core is
end entity tb_virtual_jtag_rom_stream_core;

architecture sim of tb_virtual_jtag_rom_stream_core is

    constant CLK_PERIOD : time := 20 ns;
    constant TCK_PERIOD : time := 70 ns;

    constant IR_DATA    : std_logic_vector(2 downto 0) := "001";
    constant IR_CONTROL : std_logic_vector(2 downto 0) := "010";
    constant IR_STATUS  : std_logic_vector(2 downto 0) := "011";

    signal clk             : std_logic := '0';
    signal reset           : std_logic := '1';
    signal stream_valid    : std_logic;
    signal stream_data     : std_logic_vector(7 downto 0);
    signal stream_ready    : std_logic := '1';
    signal start_pulse     : std_logic;
    signal finish_pulse    : std_logic;
    signal protocol_error  : std_logic;
    signal loader_busy     : std_logic := '0';
    signal loader_done     : std_logic := '0';
    signal loader_error    : std_logic := '0';
    signal sdram_init_done : std_logic := '0';
    signal vj_tck          : std_logic := '0';
    signal vj_tdi          : std_logic := '0';
    signal vj_ir_in        : std_logic_vector(2 downto 0) := (others => '0');
    signal vj_state_cdr    : std_logic := '0';
    signal vj_state_sdr    : std_logic := '0';
    signal vj_state_udr    : std_logic := '0';
    signal vj_tdo          : std_logic;
    signal sim_done        : boolean := false;
    signal stream_count    : natural := 0;
    signal last_stream_data: std_logic_vector(7 downto 0) := (others => '0');

    procedure wait_clk(
        constant count : in natural) is
    begin
        for i in 1 to count loop
            wait until rising_edge(clk);
        end loop;
    end procedure wait_clk;

    procedure tck_cycle(
        signal tck_out : out std_logic) is
    begin
        tck_out <= '0';
        wait for TCK_PERIOD / 2;
        tck_out <= '1';
        wait for TCK_PERIOD / 2;
    end procedure tck_cycle;

    procedure shift_dr_byte(
        signal tck_out : out std_logic;
        signal tdi_out : out std_logic;
        signal ir_out  : out std_logic_vector(2 downto 0);
        signal cdr_out : out std_logic;
        signal sdr_out : out std_logic;
        signal udr_out : out std_logic;
        constant ir_in    : in std_logic_vector(2 downto 0);
        constant value_in : in std_logic_vector(7 downto 0)) is
    begin
        ir_out <= ir_in;
        cdr_out <= '1';
        tck_cycle(tck_out);
        cdr_out <= '0';

        sdr_out <= '1';
        for i in 0 to 7 loop
            tdi_out <= value_in(i);
            tck_cycle(tck_out);
        end loop;
        sdr_out <= '0';
        tdi_out <= '0';

        udr_out <= '1';
        tck_cycle(tck_out);
        udr_out <= '0';
        tck_cycle(tck_out);
    end procedure shift_dr_byte;

    procedure read_status(
        signal tck_out : out std_logic;
        signal ir_out  : out std_logic_vector(2 downto 0);
        signal cdr_out : out std_logic;
        signal sdr_out : out std_logic;
        variable status_out : out std_logic_vector(7 downto 0)) is
    begin
        ir_out <= IR_STATUS;
        cdr_out <= '1';
        tck_cycle(tck_out);
        cdr_out <= '0';

        sdr_out <= '1';
        for i in 0 to 7 loop
            tck_cycle(tck_out);
            status_out(i) := vj_tdo;
        end loop;
        sdr_out <= '0';
        tck_cycle(tck_out);
    end procedure read_status;

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

    p_stream_monitor: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                stream_count <= 0;
                last_stream_data <= (others => '0');
            elsif stream_valid = '1' then
                stream_count <= stream_count + 1;
                last_stream_data <= stream_data;
            end if;
        end if;
    end process p_stream_monitor;

    p_stimulus: process
        variable status_v : std_logic_vector(7 downto 0);
        variable count_before_v : natural;
    begin
        report "=== tb_virtual_jtag_rom_stream_core: Starting simulation ===" severity note;

        wait_clk(5);
        reset <= '0';
        sdram_init_done <= '1';
        wait_clk(10);

        shift_dr_byte(vj_tck, vj_tdi, vj_ir_in, vj_state_cdr, vj_state_sdr, vj_state_udr, IR_CONTROL, x"01");
        wait_clk(10);
        assert start_pulse = '0'
            report "FAIL: start_pulse should be a one-cycle pulse"
            severity failure;

        stream_ready <= '0';
        shift_dr_byte(vj_tck, vj_tdi, vj_ir_in, vj_state_cdr, vj_state_sdr, vj_state_udr, IR_DATA, x"A5");
        wait_clk(10);
        assert stream_valid = '0'
            report "FAIL: stream_valid asserted while initial stream_ready was low"
            severity failure;
        stream_ready <= '1';
        wait until stream_count = 1;
        assert last_stream_data = x"A5"
            report "FAIL: first JTAG byte was not delivered to stream interface"
            severity failure;

        shift_dr_byte(vj_tck, vj_tdi, vj_ir_in, vj_state_cdr, vj_state_sdr, vj_state_udr, IR_DATA, x"3C");
        wait_clk(20);
        assert stream_valid = '0'
            report "FAIL: stream_valid asserted while stream_ready was low"
            severity failure;

        read_status(vj_tck, vj_ir_in, vj_state_cdr, vj_state_sdr, status_v);
        assert status_v(5) = '1'
            report "FAIL: status did not report pending byte while stream stalled"
            severity failure;

        stream_ready <= '1';
        wait_clk(10);
        assert stream_count >= 2
            report "FAIL: stalled JTAG byte did not produce a second stream beat"
            severity failure;
        assert last_stream_data = x"3C"
            report "FAIL: stalled JTAG byte was not delivered after stream_ready"
            severity failure;

        stream_ready <= '0';
        shift_dr_byte(vj_tck, vj_tdi, vj_ir_in, vj_state_cdr, vj_state_sdr, vj_state_udr, IR_DATA, x"55");
        shift_dr_byte(vj_tck, vj_tdi, vj_ir_in, vj_state_cdr, vj_state_sdr, vj_state_udr, IR_DATA, x"66");
        wait_clk(20);
        assert protocol_error = '1'
            report "FAIL: protocol_error did not assert on data overflow"
            severity failure;
        stream_ready <= '1';
        count_before_v := stream_count;
        wait_clk(10);
        assert stream_count >= count_before_v + 1
            report "FAIL: overflow test pending byte was not delivered"
            severity failure;

        shift_dr_byte(vj_tck, vj_tdi, vj_ir_in, vj_state_cdr, vj_state_sdr, vj_state_udr, IR_CONTROL, x"04");
        wait_clk(20);
        assert protocol_error = '0'
            report "FAIL: protocol_error did not clear through control bit 2"
            severity failure;

        shift_dr_byte(vj_tck, vj_tdi, vj_ir_in, vj_state_cdr, vj_state_sdr, vj_state_udr, IR_CONTROL, x"02");
        wait_clk(10);
        assert finish_pulse = '0'
            report "FAIL: finish_pulse should be a one-cycle pulse"
            severity failure;

        loader_busy <= '1';
        loader_done <= '0';
        loader_error <= '0';
        wait_clk(4);
        tck_cycle(vj_tck);
        tck_cycle(vj_tck);
        read_status(vj_tck, vj_ir_in, vj_state_cdr, vj_state_sdr, status_v);
        assert status_v(0) = '1' and status_v(1) = '1' and status_v(4) = '1'
            report "FAIL: status bits did not reflect ready/busy/init state"
            severity failure;

        report "=== tb_virtual_jtag_rom_stream_core: ALL TESTS PASSED ===" severity note;
        sim_done <= true;
        wait;
    end process p_stimulus;

end architecture sim;
