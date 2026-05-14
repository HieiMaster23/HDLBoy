-- =============================================================================
-- Module:      tb_bus_controller
-- Description: Testbench for the initial M4 CPU memory map
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-13
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_bus_controller is
end entity tb_bus_controller;

architecture sim of tb_bus_controller is

    constant CLK_PERIOD : time := 20 ns;

    signal clk                  : std_logic := '0';
    signal reset                : std_logic := '1';
    signal cpu_addr             : std_logic_vector(15 downto 0) := (others => '0');
    signal cpu_data_in          : std_logic_vector(7 downto 0);
    signal cpu_data_out         : std_logic_vector(7 downto 0) := (others => '0');
    signal cpu_read             : std_logic := '0';
    signal cpu_write            : std_logic := '0';
    signal cpu_ready            : std_logic;
    signal unsupported_opcode   : std_logic := '0';
    signal fb_clear_active      : std_logic := '0';
    signal fb_clear_addr        : unsigned(14 downto 0) := (others => '0');
    signal fb_we                : std_logic;
    signal fb_addr              : unsigned(14 downto 0);
    signal fb_data              : std_logic_vector(1 downto 0);
    signal led_pattern          : std_logic_vector(3 downto 0);
    signal display_digits       : std_logic_vector(15 downto 0);
    signal checker_failed       : std_logic;
    signal final_passed         : std_logic;
    signal interrupt_ack        : std_logic := '0';
    signal interrupt_vector     : std_logic_vector(2 downto 0) := "000";
    signal interrupt_enable     : std_logic_vector(4 downto 0);
    signal interrupt_flags      : std_logic_vector(4 downto 0);
    signal serial_debug_valid   : std_logic;
    signal serial_debug_data    : std_logic_vector(7 downto 0);
    signal debug_fb_write_count : std_logic_vector(7 downto 0);
    signal sim_done             : boolean := false;

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

    u_dut: entity work.bus_controller
        port map (
            clk                  => clk,
            reset                => reset,
            cpu_addr             => cpu_addr,
            cpu_data_in          => cpu_data_in,
            cpu_data_out         => cpu_data_out,
            cpu_read             => cpu_read,
            cpu_write            => cpu_write,
            cpu_ready            => cpu_ready,
            unsupported_opcode   => unsupported_opcode,
            fb_clear_active      => fb_clear_active,
            fb_clear_addr        => fb_clear_addr,
            fb_we                => fb_we,
            fb_addr              => fb_addr,
            fb_data              => fb_data,
            led_pattern          => led_pattern,
            display_digits       => display_digits,
            checker_failed       => checker_failed,
            final_passed         => final_passed,
            interrupt_ack        => interrupt_ack,
            interrupt_vector     => interrupt_vector,
            interrupt_enable     => interrupt_enable,
            interrupt_flags      => interrupt_flags,
            serial_debug_valid   => serial_debug_valid,
            serial_debug_data    => serial_debug_data,
            debug_fb_write_count => debug_fb_write_count
        );

    p_stimulus: process
        procedure bus_write(
            constant addr_in : in std_logic_vector(15 downto 0);
            constant data_in : in std_logic_vector(7 downto 0)) is
        begin
            cpu_addr <= addr_in;
            cpu_data_out <= data_in;
            cpu_read <= '0';
            cpu_write <= '1';
            wait until rising_edge(clk);
            wait for 1 ns;
            cpu_write <= '0';
        end procedure bus_write;

        procedure bus_read_check(
            constant addr_in : in std_logic_vector(15 downto 0);
            constant expected_in : in std_logic_vector(7 downto 0);
            constant message_in : in string) is
        begin
            cpu_addr <= addr_in;
            cpu_read <= '1';
            cpu_write <= '0';
            wait for 1 ns;
            while cpu_ready = '0' loop
                wait until rising_edge(clk);
                wait for 1 ns;
            end loop;
            assert cpu_data_in = expected_in
                report message_in
                severity failure;
            cpu_read <= '0';
        end procedure bus_read_check;
    begin
        report "=== tb_bus_controller: Starting simulation ===" severity note;

        reset <= '1';
        wait for CLK_PERIOD * 4;
        wait until rising_edge(clk);
        reset <= '0';
        wait for 1 ns;

        bus_read_check(x"0000", x"31", "FAIL: ROM byte at 0x0000 should be LD SP opcode");
        bus_read_check(x"0119", x"00", "FAIL: unmapped ROM byte should read 0x00");

        bus_read_check(x"FF0F", x"E0", "FAIL: IF reset value should read upper bits high");
        bus_read_check(x"FFFF", x"00", "FAIL: IE reset value should be 0x00");

        bus_write(x"FF0F", x"15");
        bus_read_check(x"FF0F", x"F5", "FAIL: IF should preserve lower interrupt flag bits and read upper bits high");
        assert interrupt_flags = "10101"
            report "FAIL: interrupt_flags output should mirror IF lower five bits"
            severity failure;

        bus_write(x"FFFF", x"1F");
        bus_read_check(x"FFFF", x"1F", "FAIL: IE should read back the written value");
        assert interrupt_enable = "11111"
            report "FAIL: interrupt_enable output should mirror IE lower five bits"
            severity failure;

        interrupt_vector <= "010";
        interrupt_ack <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        interrupt_ack <= '0';
        bus_read_check(x"FF0F", x"F1", "FAIL: interrupt acknowledge should clear the selected IF bit");
        assert interrupt_flags = "10001"
            report "FAIL: interrupt_flags should clear the acknowledged timer bit"
            severity failure;

        bus_write(x"C000", x"34");
        bus_read_check(x"C000", x"34", "FAIL: WRAM first byte should read back written data");
        bus_read_check(x"E000", x"34", "FAIL: Echo RAM should mirror WRAM first byte");

        bus_write(x"E03F", x"99");
        bus_read_check(x"C03F", x"99", "FAIL: Echo RAM writes should update the WRAM initial page");

        bus_write(x"C040", x"77");
        bus_read_check(x"C040", x"77", "FAIL: Expanded WRAM should include 0xC040");

        bus_write(x"FF82", x"5A");
        bus_read_check(x"FF82", x"5A", "FAIL: HRAM 0xFF82 should read back written data");

        bus_write(x"FFFE", x"C3");
        bus_read_check(x"FFFE", x"C3", "FAIL: HRAM 0xFFFE should read back written data");

        bus_write(x"FF80", x"0D");
        bus_read_check(x"FF80", x"0D", "FAIL: debug LED/HRAM overlay should read back written data");
        assert led_pattern = x"D"
            report "FAIL: debug LED pattern should update from 0xFF80"
            severity failure;

        bus_read_check(x"FF00", x"FF", "FAIL: JOYP reset stub should report no buttons selected or pressed");
        bus_write(x"FF00", x"20");
        bus_read_check(x"FF00", x"EF", "FAIL: JOYP stub should preserve select bits and report no pressed buttons");

        bus_write(x"FF01", x"12");
        bus_read_check(x"FF01", x"12", "FAIL: Serial SB stub should read back written data");

        bus_write(x"FF02", x"81");
        bus_read_check(x"FF02", x"81", "FAIL: Serial SC stub should read back written data");
        assert serial_debug_valid = '1' and serial_debug_data = x"12"
            report "FAIL: Serial debug pulse should expose SB when SC starts a transfer"
            severity failure;
        wait until rising_edge(clk);
        wait for 1 ns;
        assert serial_debug_valid = '0'
            report "FAIL: Serial debug valid should be a one-cycle pulse"
            severity failure;

        bus_write(x"FF04", x"AB");
        bus_read_check(x"FF04", x"00", "FAIL: DIV write should reset the divider counter");

        bus_write(x"FF05", x"56");
        bus_read_check(x"FF05", x"56", "FAIL: TIMA stub should read back written data");

        bus_write(x"FF06", x"78");
        bus_read_check(x"FF06", x"78", "FAIL: TMA stub should read back written data");

        bus_write(x"FF07", x"05");
        bus_read_check(x"FF07", x"FD", "FAIL: TAC stub should preserve lower control bits with upper bits high");

        bus_read_check(x"FF40", x"91", "FAIL: LCDC reset stub should use the DMG post-boot display default");
        bus_write(x"FF40", x"80");
        bus_read_check(x"FF40", x"80", "FAIL: LCDC stub should read back written data");

        bus_write(x"FF41", x"78");
        bus_read_check(x"FF41", x"F8", "FAIL: STAT stub should preserve writable status interrupt bits");

        bus_write(x"FF42", x"22");
        bus_write(x"FF43", x"33");
        bus_read_check(x"FF42", x"22", "FAIL: SCY stub should read back written data");
        bus_read_check(x"FF43", x"33", "FAIL: SCX stub should read back written data");
        bus_read_check(x"FF44", x"00", "FAIL: LY stub should remain zero until the PPU owns it");

        bus_write(x"FF45", x"44");
        bus_write(x"FF46", x"55");
        bus_read_check(x"FF45", x"44", "FAIL: LYC stub should read back written data");
        bus_read_check(x"FF46", x"55", "FAIL: DMA stub should read back written data");

        bus_read_check(x"FF47", x"FC", "FAIL: BGP reset stub should use the common DMG default");
        bus_write(x"FF47", x"E4");
        bus_write(x"FF48", x"D2");
        bus_write(x"FF49", x"C1");
        bus_read_check(x"FF47", x"E4", "FAIL: BGP stub should read back written data");
        bus_read_check(x"FF48", x"D2", "FAIL: OBP0 stub should read back written data");
        bus_read_check(x"FF49", x"C1", "FAIL: OBP1 stub should read back written data");

        bus_write(x"FF4A", x"66");
        bus_write(x"FF4B", x"77");
        bus_read_check(x"FF4A", x"66", "FAIL: WY stub should read back written data");
        bus_read_check(x"FF4B", x"77", "FAIL: WX stub should read back written data");

        bus_read_check(x"FF30", x"FF", "FAIL: unmapped I/O stubs should read as open bus high");

        cpu_addr <= x"8000";
        cpu_data_out <= x"03";
        cpu_read <= '0';
        cpu_write <= '1';
        wait for 1 ns;
        assert fb_we = '1' and fb_addr = to_unsigned(0, 15) and fb_data = "11"
            report "FAIL: framebuffer write window should drive fb port A"
            severity failure;
        wait until rising_edge(clk);
        wait for 1 ns;
        cpu_write <= '0';

        fb_clear_active <= '1';
        fb_clear_addr <= to_unsigned(123, 15);
        wait for 1 ns;
        assert fb_we = '1' and fb_addr = to_unsigned(123, 15) and fb_data = "00"
            report "FAIL: framebuffer clear path should override CPU writes"
            severity failure;
        fb_clear_active <= '0';

        assert checker_failed = '0'
            report "FAIL: basic map accesses should not trip the smoke checker"
            severity failure;

        assert final_passed = '0'
            report "FAIL: final_passed should remain low without smoke pass code"
            severity failure;

        report "=== tb_bus_controller: ALL TESTS PASSED ===" severity note;
        sim_done <= true;
        wait;
    end process p_stimulus;

end architecture sim;
