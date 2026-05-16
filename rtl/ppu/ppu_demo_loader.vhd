-- =============================================================================
-- Module:      ppu_demo_loader
-- Description: Small VRAM initializer for the first PPU visual demo
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-16
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-16 - Initial loader for background-only PPU demo
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ppu_demo_loader is
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        start     : in  std_logic;

        bus_addr  : out std_logic_vector(15 downto 0);
        bus_data  : out std_logic_vector(7 downto 0);
        bus_write : out std_logic;

        busy      : out std_logic;
        done      : out std_logic
    );
end entity ppu_demo_loader;

architecture rtl of ppu_demo_loader is

    constant TILE_DATA_BYTES : integer := 64;
    constant TILE_MAP_BYTES  : integer := 1024;

    type state_t is (
        S_IDLE,
        S_WRITE_TILE_DATA,
        S_WRITE_TILE_MAP,
        S_DONE
    );

    signal state_reg      : state_t;
    signal tile_data_idx  : unsigned(5 downto 0);
    signal tile_map_idx   : unsigned(9 downto 0);

    function tile_data_byte(index_in : unsigned(5 downto 0))
        return std_logic_vector is
        variable index_v : integer;
        variable row_v   : integer;
        variable byte_v  : std_logic_vector(7 downto 0);
    begin
        index_v := to_integer(index_in);
        row_v := (index_v mod 16) / 2;
        byte_v := x"00";

        case index_v / 16 is
            when 0 =>
                byte_v := x"00";
            when 1 =>
                if (index_v mod 2) = 0 then
                    if (row_v mod 2) = 0 then
                        byte_v := x"AA";
                    else
                        byte_v := x"55";
                    end if;
                else
                    if (row_v mod 2) = 0 then
                        byte_v := x"AA";
                    else
                        byte_v := x"55";
                    end if;
                end if;
            when 2 =>
                if (index_v mod 2) = 0 then
                    byte_v := x"F0";
                else
                    byte_v := x"00";
                end if;
            when others =>
                if row_v < 4 then
                    byte_v := x"FF";
                else
                    byte_v := x"00";
                end if;
        end case;

        return byte_v;
    end function tile_data_byte;

    function tile_map_byte(index_in : unsigned(9 downto 0))
        return std_logic_vector is
        variable result_v : std_logic_vector(7 downto 0);
    begin
        result_v := (others => '0');
        result_v(1) := index_in(5);
        result_v(0) := index_in(0);
        return result_v;
    end function tile_map_byte;

begin

    p_loader: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state_reg <= S_IDLE;
                tile_data_idx <= (others => '0');
                tile_map_idx <= (others => '0');
            else
                case state_reg is
                    when S_IDLE =>
                        tile_data_idx <= (others => '0');
                        tile_map_idx <= (others => '0');
                        if start = '1' then
                            state_reg <= S_WRITE_TILE_DATA;
                        end if;

                    when S_WRITE_TILE_DATA =>
                        if tile_data_idx = to_unsigned(TILE_DATA_BYTES - 1, 6) then
                            state_reg <= S_WRITE_TILE_MAP;
                        else
                            tile_data_idx <= tile_data_idx + 1;
                        end if;

                    when S_WRITE_TILE_MAP =>
                        if tile_map_idx = to_unsigned(TILE_MAP_BYTES - 1, 10) then
                            state_reg <= S_DONE;
                        else
                            tile_map_idx <= tile_map_idx + 1;
                        end if;

                    when S_DONE =>
                        state_reg <= S_DONE;

                    when others =>
                        state_reg <= S_IDLE;
                end case;
            end if;
        end if;
    end process p_loader;

    p_outputs: process(state_reg, tile_data_idx, tile_map_idx)
    begin
        bus_addr <= (others => '0');
        bus_data <= (others => '0');
        bus_write <= '0';
        busy <= '0';
        done <= '0';

        case state_reg is
            when S_IDLE =>
                null;
            when S_WRITE_TILE_DATA =>
                bus_addr <= std_logic_vector(to_unsigned(16#8000#, 16) +
                                              resize(tile_data_idx, 16));
                bus_data <= tile_data_byte(tile_data_idx);
                bus_write <= '1';
                busy <= '1';
            when S_WRITE_TILE_MAP =>
                bus_addr <= std_logic_vector(to_unsigned(16#9800#, 16) +
                                              resize(tile_map_idx, 16));
                bus_data <= tile_map_byte(tile_map_idx);
                bus_write <= '1';
                busy <= '1';
            when S_DONE =>
                done <= '1';
            when others =>
                null;
        end case;
    end process p_outputs;

end architecture rtl;
