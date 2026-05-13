-- =============================================================================
-- Module:      seven_segment_mux
-- Description: Four-digit active-low seven-segment display multiplexer
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-11
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-11 - Initial active-low 4-digit display driver
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity seven_segment_mux is
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        enable    : in  std_logic;
        digits    : in  std_logic_vector(15 downto 0);
        seg       : out std_logic_vector(7 downto 0);
        digit_n   : out std_logic_vector(3 downto 0)
    );
end entity seven_segment_mux;

architecture rtl of seven_segment_mux is

    signal mux_counter : unsigned(15 downto 0);
    signal digit_sel   : unsigned(1 downto 0);
    signal nibble      : std_logic_vector(3 downto 0);

    function encode_digit(value_in : std_logic_vector(3 downto 0)) return std_logic_vector is
        variable seg_v : std_logic_vector(7 downto 0);
    begin
        seg_v := (others => '1');

        case value_in is
            when x"0" =>
                seg_v(0) := '0'; seg_v(1) := '0'; seg_v(2) := '0';
                seg_v(3) := '0'; seg_v(4) := '0'; seg_v(5) := '0';
            when x"1" =>
                seg_v(1) := '0'; seg_v(2) := '0';
            when x"2" =>
                seg_v(0) := '0'; seg_v(1) := '0'; seg_v(3) := '0';
                seg_v(4) := '0'; seg_v(6) := '0';
            when x"3" =>
                seg_v(0) := '0'; seg_v(1) := '0'; seg_v(2) := '0';
                seg_v(3) := '0'; seg_v(6) := '0';
            when x"4" =>
                seg_v(1) := '0'; seg_v(2) := '0'; seg_v(5) := '0';
                seg_v(6) := '0';
            when x"5" =>
                seg_v(0) := '0'; seg_v(2) := '0'; seg_v(3) := '0';
                seg_v(5) := '0'; seg_v(6) := '0';
            when x"6" =>
                seg_v(0) := '0'; seg_v(2) := '0'; seg_v(3) := '0';
                seg_v(4) := '0'; seg_v(5) := '0'; seg_v(6) := '0';
            when x"7" =>
                seg_v(0) := '0'; seg_v(1) := '0'; seg_v(2) := '0';
            when x"8" =>
                seg_v(0) := '0'; seg_v(1) := '0'; seg_v(2) := '0';
                seg_v(3) := '0'; seg_v(4) := '0'; seg_v(5) := '0';
                seg_v(6) := '0';
            when x"9" =>
                seg_v(0) := '0'; seg_v(1) := '0'; seg_v(2) := '0';
                seg_v(3) := '0'; seg_v(5) := '0'; seg_v(6) := '0';
            when x"A" =>
                seg_v(0) := '0'; seg_v(1) := '0'; seg_v(2) := '0';
                seg_v(4) := '0'; seg_v(5) := '0'; seg_v(6) := '0';
            when x"B" =>
                seg_v(2) := '0'; seg_v(3) := '0'; seg_v(4) := '0';
                seg_v(5) := '0'; seg_v(6) := '0';
            when x"C" =>
                seg_v(0) := '0'; seg_v(3) := '0'; seg_v(4) := '0';
                seg_v(5) := '0';
            when x"D" =>
                seg_v(1) := '0'; seg_v(2) := '0'; seg_v(3) := '0';
                seg_v(4) := '0'; seg_v(6) := '0';
            when x"E" =>
                seg_v(0) := '0'; seg_v(3) := '0'; seg_v(4) := '0';
                seg_v(5) := '0'; seg_v(6) := '0';
            when others =>
                seg_v(0) := '0'; seg_v(4) := '0'; seg_v(5) := '0';
                seg_v(6) := '0';
        end case;

        return seg_v;
    end function encode_digit;

begin

    p_counter: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                mux_counter <= (others => '0');
            else
                mux_counter <= mux_counter + 1;
            end if;
        end if;
    end process p_counter;

    digit_sel <= mux_counter(15 downto 14);

    p_select: process(digit_sel, digits)
    begin
        case digit_sel is
            when "00" =>
                nibble  <= digits(15 downto 12);
                digit_n <= "1110";
            when "01" =>
                nibble  <= digits(11 downto 8);
                digit_n <= "1101";
            when "10" =>
                nibble  <= digits(7 downto 4);
                digit_n <= "1011";
            when others =>
                nibble  <= digits(3 downto 0);
                digit_n <= "0111";
        end case;
    end process p_select;

    p_output: process(enable, nibble)
    begin
        if enable = '1' then
            seg <= encode_digit(nibble);
        else
            seg <= (others => '1');
        end if;
    end process p_output;

end architecture rtl;
