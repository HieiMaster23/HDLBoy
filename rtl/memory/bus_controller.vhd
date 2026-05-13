-- =============================================================================
-- Module:      bus_controller
-- Description: Initial CPU memory map for M3/M4 smoke integration
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-13
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-13 - Extracted ROM, debug I/O, and framebuffer write decode
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bus_controller is
    port (
        clk                 : in  std_logic;
        reset               : in  std_logic;

        cpu_addr            : in  std_logic_vector(15 downto 0);
        cpu_data_in         : out std_logic_vector(7 downto 0);
        cpu_data_out        : in  std_logic_vector(7 downto 0);
        cpu_read            : in  std_logic;
        cpu_write           : in  std_logic;
        unsupported_opcode  : in  std_logic;

        fb_clear_active     : in  std_logic;
        fb_clear_addr       : in  unsigned(14 downto 0);
        fb_we               : out std_logic;
        fb_addr             : out unsigned(14 downto 0);
        fb_data             : out std_logic_vector(1 downto 0);

        led_pattern         : out std_logic_vector(3 downto 0);
        display_digits      : out std_logic_vector(15 downto 0);
        checker_failed      : out std_logic;
        final_passed        : out std_logic;
        debug_fb_write_count: out std_logic_vector(7 downto 0)
    );
end entity bus_controller;

architecture rtl of bus_controller is

    constant FB_BASE_ADDR       : std_logic_vector(15 downto 0) := x"8000";
    constant FB_LAST_ADDR       : std_logic_vector(15 downto 0) := x"D9FF";
    constant IO_LED_ADDR        : std_logic_vector(15 downto 0) := x"FF80";
    constant IO_STATUS_ADDR     : std_logic_vector(15 downto 0) := x"FF81";
    constant PASS_CODE          : std_logic_vector(7 downto 0)  := x"A5";
    constant EXPECTED_FB_WRITES : unsigned(7 downto 0) := to_unsigned(64, 8);
    constant ROM_LAST_INDEX     : integer := 280;

    type rom_t is array (0 to ROM_LAST_INDEX) of std_logic_vector(7 downto 0);
    constant ROM : rom_t := (
        x"31", x"FE", x"FF", x"21", x"80", x"FF", x"3E", x"01",
        x"77", x"3E", x"03", x"21", x"30", x"A3", x"77", x"21",
        x"31", x"A3", x"77", x"21", x"D2", x"A3", x"77", x"21",
        x"D3", x"A3", x"77", x"21", x"74", x"A4", x"77", x"21",
        x"75", x"A4", x"77", x"21", x"16", x"A5", x"77", x"21",
        x"17", x"A5", x"77", x"21", x"B8", x"A5", x"77", x"21",
        x"B9", x"A5", x"77", x"21", x"5A", x"A6", x"77", x"21",
        x"5B", x"A6", x"77", x"21", x"FC", x"A6", x"77", x"21",
        x"FD", x"A6", x"77", x"21", x"9E", x"A7", x"77", x"21",
        x"9F", x"A7", x"77", x"21", x"40", x"A8", x"77", x"21",
        x"41", x"A8", x"77", x"21", x"E2", x"A8", x"77", x"21",
        x"E3", x"A8", x"77", x"21", x"84", x"A9", x"77", x"21",
        x"85", x"A9", x"77", x"21", x"26", x"AA", x"77", x"21",
        x"27", x"AA", x"77", x"21", x"C8", x"AA", x"77", x"21",
        x"C9", x"AA", x"77", x"21", x"6A", x"AB", x"77", x"21",
        x"6B", x"AB", x"77", x"21", x"0C", x"AC", x"77", x"21",
        x"0D", x"AC", x"77", x"21", x"AE", x"AC", x"77", x"21",
        x"AF", x"AC", x"77", x"21", x"50", x"B7", x"77", x"21",
        x"51", x"B7", x"77", x"21", x"52", x"B7", x"77", x"21",
        x"53", x"B7", x"77", x"21", x"54", x"B7", x"77", x"21",
        x"55", x"B7", x"77", x"21", x"56", x"B7", x"77", x"21",
        x"57", x"B7", x"77", x"21", x"58", x"B7", x"77", x"21",
        x"59", x"B7", x"77", x"21", x"5A", x"B7", x"77", x"21",
        x"5B", x"B7", x"77", x"21", x"5C", x"B7", x"77", x"21",
        x"5D", x"B7", x"77", x"21", x"5E", x"B7", x"77", x"21",
        x"5F", x"B7", x"77", x"21", x"60", x"B7", x"77", x"21",
        x"61", x"B7", x"77", x"21", x"62", x"B7", x"77", x"21",
        x"63", x"B7", x"77", x"21", x"64", x"B7", x"77", x"21",
        x"65", x"B7", x"77", x"21", x"66", x"B7", x"77", x"21",
        x"67", x"B7", x"77", x"21", x"68", x"B7", x"77", x"21",
        x"69", x"B7", x"77", x"21", x"6A", x"B7", x"77", x"21",
        x"6B", x"B7", x"77", x"21", x"6C", x"B7", x"77", x"21",
        x"6D", x"B7", x"77", x"21", x"6E", x"B7", x"77", x"21",
        x"6F", x"B7", x"77", x"21", x"80", x"FF", x"3E", x"0D",
        x"77", x"21", x"81", x"FF", x"3E", x"A5", x"77", x"18",
        x"FE"
    );

    signal io_led_reg        : std_logic_vector(7 downto 0);
    signal io_status_reg     : std_logic_vector(7 downto 0);
    signal led_pattern_reg   : std_logic_vector(3 downto 0);
    signal fb_write_count    : unsigned(7 downto 0);
    signal checker_failed_reg: std_logic;
    signal final_passed_reg  : std_logic;
    signal fb_selected       : std_logic;

    function rom_byte(addr_in : std_logic_vector(15 downto 0)) return std_logic_vector is
        variable addr_u : unsigned(15 downto 0);
        variable data_v : std_logic_vector(7 downto 0);
    begin
        addr_u := unsigned(addr_in);
        if addr_u <= to_unsigned(ROM_LAST_INDEX, 16) then
            data_v := ROM(to_integer(addr_u));
        else
            data_v := x"00";
        end if;

        return data_v;
    end function rom_byte;

begin

    fb_selected <= '1' when unsigned(cpu_addr) >= unsigned(FB_BASE_ADDR) and
                            unsigned(cpu_addr) <= unsigned(FB_LAST_ADDR) else '0';

    p_memory_read: process(cpu_addr, cpu_read, io_led_reg, io_status_reg)
    begin
        if cpu_read = '1' then
            case cpu_addr is
                when IO_LED_ADDR =>
                    cpu_data_in <= io_led_reg;
                when IO_STATUS_ADDR =>
                    cpu_data_in <= io_status_reg;
                when others =>
                    cpu_data_in <= rom_byte(cpu_addr);
            end case;
        else
            cpu_data_in <= rom_byte(cpu_addr);
        end if;
    end process p_memory_read;

    p_memory_write: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                io_led_reg <= (others => '0');
                io_status_reg <= (others => '0');
                fb_write_count <= (others => '0');
                led_pattern_reg <= x"0";
                checker_failed_reg <= '0';
                final_passed_reg <= '0';
            else
                if unsupported_opcode = '1' then
                    checker_failed_reg <= '1';
                end if;

                if cpu_write = '1' then
                    if fb_selected = '1' then
                        if fb_write_count < EXPECTED_FB_WRITES then
                            fb_write_count <= fb_write_count + 1;
                        else
                            checker_failed_reg <= '1';
                        end if;
                    end if;

                    case cpu_addr is
                        when IO_LED_ADDR =>
                            io_led_reg <= cpu_data_out;
                            led_pattern_reg <= cpu_data_out(3 downto 0);
                        when IO_STATUS_ADDR =>
                            io_status_reg <= cpu_data_out;
                            if cpu_data_out = PASS_CODE and checker_failed_reg = '0' and
                               led_pattern_reg = x"D" and
                               fb_write_count = EXPECTED_FB_WRITES then
                                final_passed_reg <= '1';
                            else
                                checker_failed_reg <= '1';
                            end if;
                        when others =>
                            null;
                    end case;
                end if;
            end if;
        end if;
    end process p_memory_write;

    fb_we   <= '1' when fb_clear_active = '1' else cpu_write and fb_selected;
    fb_addr <= fb_clear_addr when fb_clear_active = '1' else unsigned(cpu_addr(14 downto 0));
    fb_data <= "00" when fb_clear_active = '1' else cpu_data_out(1 downto 0);

    led_pattern <= led_pattern_reg;
    checker_failed <= checker_failed_reg;
    final_passed <= final_passed_reg;
    debug_fb_write_count <= std_logic_vector(fb_write_count);

    display_digits <= x"1234" when final_passed_reg = '1' and checker_failed_reg = '0' else
                      x"EEEE" when checker_failed_reg = '1' else
                      x"0000";

end architecture rtl;
