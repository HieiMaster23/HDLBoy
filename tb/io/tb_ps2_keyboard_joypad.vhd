-- =============================================================================
-- Module:      tb_ps2_keyboard_joypad
-- Description: Self-checking testbench for the compact PS/2 JOYP mapper
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-22
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_ps2_keyboard_joypad is
end entity tb_ps2_keyboard_joypad;

architecture sim of tb_ps2_keyboard_joypad is

    constant CLK_PERIOD : time := 20 ns;
    constant PS2_HALF_PERIOD : time := 20 us;

    signal clk        : std_logic := '0';
    signal reset      : std_logic := '1';
    signal ps2_clk    : std_logic := '1';
    signal ps2_data   : std_logic := '1';
    signal btn_right  : std_logic;
    signal btn_left   : std_logic;
    signal btn_up     : std_logic;
    signal btn_down   : std_logic;
    signal btn_a      : std_logic;
    signal btn_b      : std_logic;
    signal btn_select : std_logic;
    signal btn_start  : std_logic;
    signal sim_done   : boolean := false;

    function odd_parity(data : std_logic_vector(7 downto 0))
        return std_logic is
        variable parity_v : std_logic;
    begin
        parity_v := '1';
        for i in data'range loop
            parity_v := parity_v xor data(i);
        end loop;
        return parity_v;
    end function odd_parity;

    procedure send_ps2_byte(
        signal ps2_clk_s  : out std_logic;
        signal ps2_data_s : out std_logic;
        constant data     : in  std_logic_vector(7 downto 0)) is
    begin
        ps2_data_s <= '0';
        wait for PS2_HALF_PERIOD;
        ps2_clk_s <= '0';
        wait for PS2_HALF_PERIOD;
        ps2_clk_s <= '1';

        for i in 0 to 7 loop
            ps2_data_s <= data(i);
            wait for PS2_HALF_PERIOD;
            ps2_clk_s <= '0';
            wait for PS2_HALF_PERIOD;
            ps2_clk_s <= '1';
        end loop;

        ps2_data_s <= odd_parity(data);
        wait for PS2_HALF_PERIOD;
        ps2_clk_s <= '0';
        wait for PS2_HALF_PERIOD;
        ps2_clk_s <= '1';

        ps2_data_s <= '1';
        wait for PS2_HALF_PERIOD;
        ps2_clk_s <= '0';
        wait for PS2_HALF_PERIOD;
        ps2_clk_s <= '1';
        wait for PS2_HALF_PERIOD;
    end procedure send_ps2_byte;

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

    u_dut: entity work.ps2_keyboard_joypad
        port map (
            clk        => clk,
            reset      => reset,
            ps2_clk    => ps2_clk,
            ps2_data   => ps2_data,
            btn_right  => btn_right,
            btn_left   => btn_left,
            btn_up     => btn_up,
            btn_down   => btn_down,
            btn_a      => btn_a,
            btn_b      => btn_b,
            btn_select => btn_select,
            btn_start  => btn_start
        );

    p_stimulus: process
    begin
        report "=== tb_ps2_keyboard_joypad: Starting simulation ===" severity note;

        reset <= '1';
        wait for CLK_PERIOD * 10;
        reset <= '0';
        wait for CLK_PERIOD * 10;

        send_ps2_byte(ps2_clk, ps2_data, x"23");
        wait for CLK_PERIOD * 20;
        assert btn_right = '1'
            report "FAIL: D make did not assert Right"
            severity failure;

        send_ps2_byte(ps2_clk, ps2_data, x"F0");
        send_ps2_byte(ps2_clk, ps2_data, x"23");
        wait for CLK_PERIOD * 20;
        assert btn_right = '0'
            report "FAIL: D break did not release Right"
            severity failure;

        send_ps2_byte(ps2_clk, ps2_data, x"1D");
        send_ps2_byte(ps2_clk, ps2_data, x"3B");
        send_ps2_byte(ps2_clk, ps2_data, x"29");
        wait for CLK_PERIOD * 20;
        assert btn_up = '1' and btn_a = '1' and btn_select = '1'
            report "FAIL: W/J/Space make mapping failed"
            severity failure;

        send_ps2_byte(ps2_clk, ps2_data, x"F0");
        send_ps2_byte(ps2_clk, ps2_data, x"1D");
        send_ps2_byte(ps2_clk, ps2_data, x"F0");
        send_ps2_byte(ps2_clk, ps2_data, x"3B");
        send_ps2_byte(ps2_clk, ps2_data, x"F0");
        send_ps2_byte(ps2_clk, ps2_data, x"29");
        wait for CLK_PERIOD * 20;
        assert btn_up = '0' and btn_a = '0' and btn_select = '0'
            report "FAIL: W/J/Space break mapping failed"
            severity failure;

        send_ps2_byte(ps2_clk, ps2_data, x"42");
        send_ps2_byte(ps2_clk, ps2_data, x"5A");
        send_ps2_byte(ps2_clk, ps2_data, x"1C");
        send_ps2_byte(ps2_clk, ps2_data, x"1B");
        wait for CLK_PERIOD * 20;
        assert btn_b = '1' and btn_start = '1' and btn_left = '1' and btn_down = '1'
            report "FAIL: K/Enter/A/S make mapping failed"
            severity failure;

        report "=== tb_ps2_keyboard_joypad: ALL TESTS PASSED ===" severity note;
        sim_done <= true;
        wait;
    end process p_stimulus;

end architecture sim;
