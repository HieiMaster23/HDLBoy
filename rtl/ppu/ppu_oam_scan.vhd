-- =============================================================================
-- Module:      ppu_oam_scan
-- Description: Initial Game Boy OAM scan candidate detector
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-20
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-20 - Initial scanline sprite candidate detector
-- =============================================================================
-- Scans the 40 DMG OAM entries in two cycles per sprite, matching the 80-dot
-- Mode 2 window used by the current PPU scheduler. This slice only records up
-- to 10 candidate sprite indices for the selected scanline; sprite fetching,
-- priority, and pixel composition are intentionally left for later slices.
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ppu_oam_scan is
    port (
        clk               : in  std_logic;
        reset             : in  std_logic;
        start             : in  std_logic;
        current_line      : in  unsigned(7 downto 0);
        lcdc              : in  std_logic_vector(7 downto 0);

        oam_addr          : out unsigned(7 downto 0);
        oam_read          : out std_logic;
        oam_data          : in  std_logic_vector(7 downto 0);

        candidate_count   : out unsigned(3 downto 0);
        candidate_indices : out std_logic_vector(79 downto 0);
        busy              : out std_logic;
        done              : out std_logic
    );
end entity ppu_oam_scan;

architecture rtl of ppu_oam_scan is

    constant SPRITE_COUNT       : integer := 40;
    constant MAX_LINE_SPRITES   : integer := 10;

    type state_t is (
        S_IDLE,
        S_REQ_Y,
        S_CAPTURE_Y,
        S_DONE
    );

    signal state_reg             : state_t;
    signal sprite_index_reg      : unsigned(5 downto 0);
    signal oam_addr_reg          : unsigned(7 downto 0);
    signal candidate_count_reg   : unsigned(3 downto 0);
    signal candidate_indices_reg : std_logic_vector(79 downto 0);

    function sprite_visible(
        sprite_y_in  : std_logic_vector(7 downto 0);
        line_in      : unsigned(7 downto 0);
        tall_sprite  : std_logic)
        return std_logic is
        variable line_plus_16_v : unsigned(8 downto 0);
        variable sprite_y_v     : unsigned(8 downto 0);
        variable sprite_end_v   : unsigned(8 downto 0);
    begin
        line_plus_16_v := resize(line_in, 9) + to_unsigned(16, 9);
        sprite_y_v := resize(unsigned(sprite_y_in), 9);

        if tall_sprite = '1' then
            sprite_end_v := sprite_y_v + to_unsigned(16, 9);
        else
            sprite_end_v := sprite_y_v + to_unsigned(8, 9);
        end if;

        if line_plus_16_v >= sprite_y_v and line_plus_16_v < sprite_end_v then
            return '1';
        end if;

        return '0';
    end function sprite_visible;

begin

    p_scan: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state_reg <= S_IDLE;
                sprite_index_reg <= (others => '0');
                oam_addr_reg <= (others => '0');
                candidate_count_reg <= (others => '0');
                candidate_indices_reg <= (others => '0');
            else
                case state_reg is
                    when S_IDLE =>
                        if start = '1' then
                            sprite_index_reg <= (others => '0');
                            oam_addr_reg <= (others => '0');
                            candidate_count_reg <= (others => '0');
                            candidate_indices_reg <= (others => '0');
                            state_reg <= S_REQ_Y;
                        end if;

                    when S_REQ_Y =>
                        state_reg <= S_CAPTURE_Y;

                    when S_CAPTURE_Y =>
                        if lcdc(1) = '1' and
                           sprite_visible(oam_data, current_line, lcdc(2)) = '1' and
                           candidate_count_reg < to_unsigned(MAX_LINE_SPRITES, 4) then
                            case candidate_count_reg is
                                when "0000" =>
                                    candidate_indices_reg(7 downto 0) <=
                                        "00" & std_logic_vector(sprite_index_reg);
                                when "0001" =>
                                    candidate_indices_reg(15 downto 8) <=
                                        "00" & std_logic_vector(sprite_index_reg);
                                when "0010" =>
                                    candidate_indices_reg(23 downto 16) <=
                                        "00" & std_logic_vector(sprite_index_reg);
                                when "0011" =>
                                    candidate_indices_reg(31 downto 24) <=
                                        "00" & std_logic_vector(sprite_index_reg);
                                when "0100" =>
                                    candidate_indices_reg(39 downto 32) <=
                                        "00" & std_logic_vector(sprite_index_reg);
                                when "0101" =>
                                    candidate_indices_reg(47 downto 40) <=
                                        "00" & std_logic_vector(sprite_index_reg);
                                when "0110" =>
                                    candidate_indices_reg(55 downto 48) <=
                                        "00" & std_logic_vector(sprite_index_reg);
                                when "0111" =>
                                    candidate_indices_reg(63 downto 56) <=
                                        "00" & std_logic_vector(sprite_index_reg);
                                when "1000" =>
                                    candidate_indices_reg(71 downto 64) <=
                                        "00" & std_logic_vector(sprite_index_reg);
                                when others =>
                                    candidate_indices_reg(79 downto 72) <=
                                        "00" & std_logic_vector(sprite_index_reg);
                            end case;

                            candidate_count_reg <= candidate_count_reg + 1;
                        end if;

                        if sprite_index_reg = to_unsigned(SPRITE_COUNT - 1, 6) then
                            state_reg <= S_DONE;
                        else
                            sprite_index_reg <= sprite_index_reg + 1;
                            oam_addr_reg <= resize(sprite_index_reg + 1, 8) sll 2;
                            state_reg <= S_REQ_Y;
                        end if;

                    when S_DONE =>
                        state_reg <= S_IDLE;

                    when others =>
                        state_reg <= S_IDLE;
                end case;
            end if;
        end if;
    end process p_scan;

    oam_addr <= oam_addr_reg;
    oam_read <= '1' when state_reg = S_REQ_Y or state_reg = S_CAPTURE_Y else '0';
    candidate_count <= candidate_count_reg;
    candidate_indices <= candidate_indices_reg;
    busy <= '1' when state_reg = S_REQ_Y or state_reg = S_CAPTURE_Y else '0';
    done <= '1' when state_reg = S_DONE else '0';

end architecture rtl;
