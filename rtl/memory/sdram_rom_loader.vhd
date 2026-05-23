-- =============================================================================
-- Module:      sdram_rom_loader
-- Description: Byte-stream ROM loader that writes packed words into SDRAM
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-23
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-23 - Initial byte stream to SDRAM command bridge
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sdram_rom_loader is
    generic (
        G_ADDR_WIDTH : natural := 22
    );
    port (
        clk               : in  std_logic;
        reset             : in  std_logic;

        start             : in  std_logic;
        finish            : in  std_logic;
        stream_valid      : in  std_logic;
        stream_data       : in  std_logic_vector(7 downto 0);
        stream_ready      : out std_logic;

        busy              : out std_logic;
        done              : out std_logic;
        error             : out std_logic;
        loaded_words      : out unsigned(G_ADDR_WIDTH - 1 downto 0);

        sdram_ready       : in  std_logic;
        sdram_cmd_accept  : in  std_logic;
        sdram_cmd_valid   : out std_logic;
        sdram_cmd_write   : out std_logic;
        sdram_cmd_addr    : out unsigned(G_ADDR_WIDTH - 1 downto 0);
        sdram_write_data  : out std_logic_vector(15 downto 0);
        sdram_byte_enable : out std_logic_vector(1 downto 0)
    );
end entity sdram_rom_loader;

architecture rtl of sdram_rom_loader is

    type state_t is (
        S_IDLE,
        S_WAIT_LOW,
        S_WAIT_HIGH,
        S_WRITE_REQ,
        S_WRITE_WAIT,
        S_DONE,
        S_ERROR
    );

    signal state_reg       : state_t;
    signal addr_reg        : unsigned(G_ADDR_WIDTH - 1 downto 0);
    signal low_byte_reg    : std_logic_vector(7 downto 0);
    signal write_word_reg  : std_logic_vector(15 downto 0);
    signal byte_enable_reg : std_logic_vector(1 downto 0);
    signal finish_write_reg: std_logic;
    signal done_reg        : std_logic;
    signal error_reg       : std_logic;

    function at_last_address(value_in : unsigned) return boolean is
        variable all_ones_v : unsigned(value_in'range);
    begin
        all_ones_v := (others => '1');
        return value_in = all_ones_v;
    end function at_last_address;

begin

    stream_ready <= '1' when state_reg = S_WAIT_LOW or state_reg = S_WAIT_HIGH else '0';
    busy <= '1' when state_reg = S_WAIT_LOW or state_reg = S_WAIT_HIGH or
                     state_reg = S_WRITE_REQ or state_reg = S_WRITE_WAIT else '0';
    done <= done_reg;
    error <= error_reg;
    loaded_words <= addr_reg;

    sdram_cmd_valid <= '1' when state_reg = S_WRITE_REQ else '0';
    sdram_cmd_write <= '1';
    sdram_cmd_addr <= addr_reg;
    sdram_write_data <= write_word_reg;
    sdram_byte_enable <= byte_enable_reg;

    p_loader: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state_reg <= S_IDLE;
                addr_reg <= (others => '0');
                low_byte_reg <= (others => '0');
                write_word_reg <= (others => '0');
                byte_enable_reg <= "11";
                finish_write_reg <= '0';
                done_reg <= '0';
                error_reg <= '0';
            else
                case state_reg is
                    when S_IDLE =>
                        if start = '1' then
                            addr_reg <= (others => '0');
                            done_reg <= '0';
                            error_reg <= '0';
                            byte_enable_reg <= "11";
                            finish_write_reg <= '0';
                            state_reg <= S_WAIT_LOW;
                        end if;

                    when S_WAIT_LOW =>
                        if stream_valid = '1' then
                            low_byte_reg <= stream_data;
                            state_reg <= S_WAIT_HIGH;
                        elsif finish = '1' then
                            done_reg <= '1';
                            state_reg <= S_DONE;
                        end if;

                    when S_WAIT_HIGH =>
                        if stream_valid = '1' then
                            write_word_reg <= stream_data & low_byte_reg;
                            byte_enable_reg <= "11";
                            finish_write_reg <= '0';
                            state_reg <= S_WRITE_REQ;
                        elsif finish = '1' then
                            write_word_reg <= x"00" & low_byte_reg;
                            byte_enable_reg <= "01";
                            finish_write_reg <= '1';
                            state_reg <= S_WRITE_REQ;
                        end if;

                    when S_WRITE_REQ =>
                        if sdram_cmd_accept = '1' then
                            state_reg <= S_WRITE_WAIT;
                        end if;

                    when S_WRITE_WAIT =>
                        if sdram_ready = '1' then
                            if at_last_address(addr_reg) then
                                done_reg <= '1';
                                state_reg <= S_DONE;
                            elsif finish_write_reg = '1' then
                                addr_reg <= addr_reg + 1;
                                finish_write_reg <= '0';
                                done_reg <= '1';
                                state_reg <= S_DONE;
                            else
                                addr_reg <= addr_reg + 1;
                                state_reg <= S_WAIT_LOW;
                            end if;
                        end if;

                    when S_DONE =>
                        if start = '1' then
                            addr_reg <= (others => '0');
                            done_reg <= '0';
                            error_reg <= '0';
                            byte_enable_reg <= "11";
                            finish_write_reg <= '0';
                            state_reg <= S_WAIT_LOW;
                        end if;

                    when S_ERROR =>
                        if start = '1' then
                            addr_reg <= (others => '0');
                            done_reg <= '0';
                            error_reg <= '0';
                            byte_enable_reg <= "11";
                            finish_write_reg <= '0';
                            state_reg <= S_WAIT_LOW;
                        end if;

                    when others =>
                        error_reg <= '1';
                        state_reg <= S_ERROR;
                end case;
            end if;
        end if;
    end process p_loader;

end architecture rtl;
