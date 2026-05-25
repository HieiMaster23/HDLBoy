-- =============================================================================
-- Module:      sdram_rom_reader
-- Description: ROM-only CPU byte reader backed by the SDRAM word interface
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-25
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-25 - Initial ROM-only SDRAM read bridge for 32 KiB cartridges
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sdram_rom_reader is
    generic (
        G_ADDR_WIDTH : natural := 22
    );
    port (
        clk               : in  std_logic;
        reset             : in  std_logic;

        cpu_addr          : in  std_logic_vector(15 downto 0);
        cpu_read          : in  std_logic;
        rom_data          : out std_logic_vector(7 downto 0);
        rom_ready         : out std_logic;

        sdram_ready       : in  std_logic;
        sdram_cmd_accept  : in  std_logic;
        sdram_read_valid  : in  std_logic;
        sdram_read_data   : in  std_logic_vector(15 downto 0);
        sdram_cmd_valid   : out std_logic;
        sdram_cmd_write   : out std_logic;
        sdram_cmd_addr    : out unsigned(G_ADDR_WIDTH - 1 downto 0);
        sdram_write_data  : out std_logic_vector(15 downto 0);
        sdram_byte_enable : out std_logic_vector(1 downto 0)
    );
end entity sdram_rom_reader;

architecture rtl of sdram_rom_reader is

    type state_t is (
        S_IDLE,
        S_CMD,
        S_WAIT_DATA,
        S_READY
    );

    signal state_reg       : state_t;
    signal addr_reg        : std_logic_vector(15 downto 0);
    signal word_addr_reg   : unsigned(G_ADDR_WIDTH - 1 downto 0);
    signal data_reg        : std_logic_vector(7 downto 0);
    signal ready_reg       : std_logic;
    signal cache_valid_reg : std_logic;
    signal cache_addr_reg  : std_logic_vector(15 downto 0);
    signal cache_data_reg  : std_logic_vector(7 downto 0);

    function rom_selected(addr_in : std_logic_vector(15 downto 0)) return boolean is
    begin
        return unsigned(addr_in) <= x"7FFF";
    end function rom_selected;

    function word_address(addr_in : std_logic_vector(15 downto 0)) return unsigned is
        variable word_v : unsigned(G_ADDR_WIDTH - 1 downto 0);
    begin
        word_v := (others => '0');
        word_v(14 downto 0) := unsigned(addr_in(15 downto 1));
        return word_v;
    end function word_address;

    function select_byte(
        word_in : std_logic_vector(15 downto 0);
        addr_in : std_logic_vector(15 downto 0))
        return std_logic_vector is
    begin
        if addr_in(0) = '0' then
            return word_in(7 downto 0);
        else
            return word_in(15 downto 8);
        end if;
    end function select_byte;

begin

    rom_data <= data_reg;
    rom_ready <= ready_reg when cpu_read = '1' and cpu_addr = addr_reg else '0';
    sdram_cmd_valid <= '1' when state_reg = S_CMD else '0';
    sdram_cmd_write <= '0';
    sdram_cmd_addr <= word_addr_reg;
    sdram_write_data <= (others => '0');
    sdram_byte_enable <= "11";

    p_reader: process(clk)
        variable byte_v : std_logic_vector(7 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state_reg <= S_IDLE;
                addr_reg <= (others => '0');
                word_addr_reg <= (others => '0');
                data_reg <= (others => '0');
                ready_reg <= '0';
                cache_valid_reg <= '0';
                cache_addr_reg <= (others => '0');
                cache_data_reg <= (others => '0');
            else
                case state_reg is
                    when S_IDLE =>
                        ready_reg <= '0';
                        if cpu_read = '1' and rom_selected(cpu_addr) then
                            addr_reg <= cpu_addr;
                            word_addr_reg <= word_address(cpu_addr);

                            if cache_valid_reg = '1' and cache_addr_reg = cpu_addr then
                                data_reg <= cache_data_reg;
                                ready_reg <= '1';
                                state_reg <= S_READY;
                            elsif sdram_ready = '1' then
                                state_reg <= S_CMD;
                            end if;
                        end if;

                    when S_CMD =>
                        if sdram_cmd_accept = '1' then
                            state_reg <= S_WAIT_DATA;
                        end if;

                    when S_WAIT_DATA =>
                        if sdram_read_valid = '1' then
                            byte_v := select_byte(sdram_read_data, addr_reg);
                            data_reg <= byte_v;
                            ready_reg <= '1';
                            cache_valid_reg <= '1';
                            cache_addr_reg <= addr_reg;
                            cache_data_reg <= byte_v;
                            state_reg <= S_READY;
                        end if;

                    when S_READY =>
                        if cpu_read = '1' and cpu_addr = addr_reg then
                            ready_reg <= '1';
                        else
                            ready_reg <= '0';
                            state_reg <= S_IDLE;
                        end if;

                    when others =>
                        ready_reg <= '0';
                        state_reg <= S_IDLE;
                end case;
            end if;
        end if;
    end process p_reader;

end architecture rtl;
