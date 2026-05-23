-- =============================================================================
-- Module:      ps2_keyboard_joypad
-- Description: Minimal PS/2 Set-2 keyboard mapper for Game Boy joypad buttons
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-22
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-22 - Initial compact PS/2 make/break decoder for JOYP inputs
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ps2_keyboard_joypad is
    port (
        clk        : in  std_logic;
        reset      : in  std_logic;
        ps2_clk    : in  std_logic;
        ps2_data   : in  std_logic;

        btn_right  : out std_logic;
        btn_left   : out std_logic;
        btn_up     : out std_logic;
        btn_down   : out std_logic;
        btn_a      : out std_logic;
        btn_b      : out std_logic;
        btn_select : out std_logic;
        btn_start  : out std_logic
    );
end entity ps2_keyboard_joypad;

architecture rtl of ps2_keyboard_joypad is

    constant PS2_BREAK_CODE : std_logic_vector(7 downto 0) := x"F0";
    constant PS2_EXT_CODE   : std_logic_vector(7 downto 0) := x"E0";
    constant KEY_W          : std_logic_vector(7 downto 0) := x"1D";
    constant KEY_A          : std_logic_vector(7 downto 0) := x"1C";
    constant KEY_S          : std_logic_vector(7 downto 0) := x"1B";
    constant KEY_D          : std_logic_vector(7 downto 0) := x"23";
    constant KEY_J          : std_logic_vector(7 downto 0) := x"3B";
    constant KEY_K          : std_logic_vector(7 downto 0) := x"42";
    constant KEY_ENTER      : std_logic_vector(7 downto 0) := x"5A";
    constant KEY_SPACE      : std_logic_vector(7 downto 0) := x"29";

    signal ps2_clk_sync     : std_logic_vector(2 downto 0);
    signal ps2_data_sync    : std_logic_vector(2 downto 0);
    signal ps2_falling_edge : std_logic;
    signal bit_count_reg    : unsigned(3 downto 0);
    signal shift_reg        : std_logic_vector(7 downto 0);
    signal release_pending_reg : std_logic;

    signal btn_right_reg    : std_logic;
    signal btn_left_reg     : std_logic;
    signal btn_up_reg       : std_logic;
    signal btn_down_reg     : std_logic;
    signal btn_a_reg        : std_logic;
    signal btn_b_reg        : std_logic;
    signal btn_select_reg   : std_logic;
    signal btn_start_reg    : std_logic;

begin

    ps2_falling_edge <= '1' when ps2_clk_sync(2 downto 1) = "10" else '0';

    p_decode: process(clk)
        variable pressed_v : std_logic;
        variable code_v    : std_logic_vector(7 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                ps2_clk_sync <= (others => '1');
                ps2_data_sync <= (others => '1');
                bit_count_reg <= (others => '0');
                shift_reg <= (others => '0');
                release_pending_reg <= '0';
                btn_right_reg <= '0';
                btn_left_reg <= '0';
                btn_up_reg <= '0';
                btn_down_reg <= '0';
                btn_a_reg <= '0';
                btn_b_reg <= '0';
                btn_select_reg <= '0';
                btn_start_reg <= '0';
            else
                ps2_clk_sync <= ps2_clk_sync(1 downto 0) & ps2_clk;
                ps2_data_sync <= ps2_data_sync(1 downto 0) & ps2_data;

                if ps2_falling_edge = '1' then
                    if bit_count_reg = to_unsigned(0, 4) then
                        if ps2_data_sync(2) = '0' then
                            bit_count_reg <= bit_count_reg + 1;
                        end if;
                    elsif bit_count_reg >= to_unsigned(1, 4) and
                          bit_count_reg <= to_unsigned(8, 4) then
                        shift_reg(to_integer(bit_count_reg) - 1) <= ps2_data_sync(2);
                        bit_count_reg <= bit_count_reg + 1;
                    elsif bit_count_reg = to_unsigned(9, 4) then
                        bit_count_reg <= bit_count_reg + 1;
                    else
                        code_v := shift_reg;
                        bit_count_reg <= (others => '0');

                        if ps2_data_sync(2) = '1' then
                            if code_v = PS2_BREAK_CODE then
                                release_pending_reg <= '1';
                            elsif code_v = PS2_EXT_CODE then
                                null;
                            else
                                pressed_v := not release_pending_reg;
                                release_pending_reg <= '0';

                                case code_v is
                                    when KEY_D =>
                                        btn_right_reg <= pressed_v;
                                    when KEY_A =>
                                        btn_left_reg <= pressed_v;
                                    when KEY_W =>
                                        btn_up_reg <= pressed_v;
                                    when KEY_S =>
                                        btn_down_reg <= pressed_v;
                                    when KEY_J =>
                                        btn_a_reg <= pressed_v;
                                    when KEY_K =>
                                        btn_b_reg <= pressed_v;
                                    when KEY_SPACE =>
                                        btn_select_reg <= pressed_v;
                                    when KEY_ENTER =>
                                        btn_start_reg <= pressed_v;
                                    when others =>
                                        null;
                                end case;
                            end if;
                        else
                            release_pending_reg <= '0';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process p_decode;

    btn_right <= btn_right_reg;
    btn_left <= btn_left_reg;
    btn_up <= btn_up_reg;
    btn_down <= btn_down_reg;
    btn_a <= btn_a_reg;
    btn_b <= btn_b_reg;
    btn_select <= btn_select_reg;
    btn_start <= btn_start_reg;

end architecture rtl;
