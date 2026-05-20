-- =============================================================================
-- Module:      ppu_background_renderer
-- Description: Minimal scanline-oriented background renderer using VRAM
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-16
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-16 - Initial background-only PPU slice
-- 2026-05-18 - Added SCX/SCY background coordinate offsets
-- 2026-05-19 - Added explicit scanline progression signals
-- 2026-05-19 - Added initial PPU mode scheduler outputs
-- 2026-05-20 - Added dot-based scanline scheduler for LY/STAT foundation
-- 2026-05-20 - Added LCD enable input for initial LCDC bit 7 behavior
-- 2026-05-20 - Converted frame completion into a continuous frame loop
-- 2026-05-20 - Applied BGP palette lookup before framebuffer writes
-- 2026-05-20 - Added initial LCDC background tile-map/data selection
-- 2026-05-20 - Added first sprite fetch/composition slice for one candidate
-- 2026-05-20 - Added OBP1, BG/OBJ priority, and two-candidate composition
-- 2026-05-20 - Expanded sprite composition storage to the 10 per-line candidates
-- =============================================================================
-- This is the first PPU foundation slice, not the final scanline-accurate DMG
-- pipeline. It renders the background tile map selected by LCDC bit 3 and the
-- tile data addressing mode selected by LCDC bit 4, then fills the framebuffer
-- one visible scanline at a time after start. After the first start pulse, the
-- renderer loops continuously while LCD is enabled. The dot scheduler exposes
-- the DMG 456-dot line structure for LY/STAT/IF work while the pixel fetch path
-- is still intentionally simple and background-only.
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ppu_background_renderer is
    port (
        clk           : in  std_logic;
        reset         : in  std_logic;
        start         : in  std_logic;
        lcd_enable    : in  std_logic;
        lcdc          : in  std_logic_vector(7 downto 0);
        scroll_y      : in  std_logic_vector(7 downto 0);
        scroll_x      : in  std_logic_vector(7 downto 0);
        bgp           : in  std_logic_vector(7 downto 0);
        obp0          : in  std_logic_vector(7 downto 0);
        obp1          : in  std_logic_vector(7 downto 0);

        sprite_candidate_count   : in  unsigned(3 downto 0);
        sprite_candidate_indices : in  std_logic_vector(79 downto 0);

        vram_addr     : out unsigned(12 downto 0);
        vram_data     : in  std_logic_vector(7 downto 0);

        oam_addr      : out unsigned(7 downto 0);
        oam_read      : out std_logic;
        oam_data      : in  std_logic_vector(7 downto 0);

        fb_we         : out std_logic;
        fb_addr       : out unsigned(14 downto 0);
        fb_data       : out std_logic_vector(1 downto 0);

        current_line  : out unsigned(7 downto 0);
        current_dot   : out unsigned(8 downto 0);
        line_active   : out std_logic;
        line_done     : out std_logic;
        ppu_mode      : out std_logic_vector(1 downto 0);
        busy          : out std_logic;
        done          : out std_logic
    );
end entity ppu_background_renderer;

architecture rtl of ppu_background_renderer is

    constant SCREEN_WIDTH      : integer := 160;
    constant SCREEN_HEIGHT     : integer := 144;
    constant DOTS_PER_LINE     : integer := 456;
    constant MODE2_DOTS        : integer := 80;
    constant MODE3_DOTS        : integer := 172;
    constant MODE3_FIRST_DOT   : integer := MODE2_DOTS;
    constant MODE3_LAST_DOT    : integer := MODE2_DOTS + MODE3_DOTS - 1;
    constant VBLANK_LAST_LINE  : integer := 153;
    constant TILE_MAP_0_BASE    : unsigned(12 downto 0) := to_unsigned(16#1800#, 13);
    constant TILE_MAP_1_BASE    : unsigned(12 downto 0) := to_unsigned(16#1C00#, 13);
    constant TILE_DATA_SIGNED_ZERO_BASE : unsigned(12 downto 0) :=
        to_unsigned(16#1000#, 13);
    constant MAX_COMPOSE_SPRITES : integer := 10;

    type sprite_byte_array_t is array (0 to MAX_COMPOSE_SPRITES - 1)
        of std_logic_vector(7 downto 0);
    type sprite_valid_array_t is array (0 to MAX_COMPOSE_SPRITES - 1)
        of std_logic;

    type state_t is (
        S_IDLE,
        S_MODE2,
        S_SPRITE_Y_REQ,
        S_SPRITE_Y_CAPTURE,
        S_SPRITE_X_REQ,
        S_SPRITE_X_CAPTURE,
        S_SPRITE_TILE_REQ,
        S_SPRITE_TILE_CAPTURE,
        S_SPRITE_ATTR_REQ,
        S_SPRITE_ATTR_CAPTURE,
        S_SPRITE_LOW_REQ,
        S_SPRITE_LOW_CAPTURE,
        S_SPRITE_HIGH_REQ,
        S_SPRITE_HIGH_CAPTURE,
        S_MAP_REQ,
        S_MAP_CAPTURE,
        S_TILE_LOW_REQ,
        S_TILE_LOW_CAPTURE,
        S_TILE_HIGH_REQ,
        S_TILE_HIGH_CAPTURE,
        S_WRITE_PIXEL,
        S_MODE3_TAIL,
        S_HBLANK,
        S_VBLANK,
        S_DONE
    );

    signal state_reg      : state_t;
    signal pixel_x_reg    : unsigned(7 downto 0);
    signal pixel_y_reg    : unsigned(7 downto 0);
    signal dot_count_reg  : unsigned(8 downto 0);
    signal fb_addr_reg    : unsigned(14 downto 0);
    signal tile_index_reg : std_logic_vector(7 downto 0);
    signal tile_low_reg   : std_logic_vector(7 downto 0);
    signal tile_high_reg  : std_logic_vector(7 downto 0);
    signal sprite_valid_reg : sprite_valid_array_t;
    signal sprite_index_reg : unsigned(7 downto 0);
    signal sprite_slot_reg  : integer range 0 to MAX_COMPOSE_SPRITES - 1;
    signal sprite_y_reg     : std_logic_vector(7 downto 0);
    signal sprite_x_reg     : sprite_byte_array_t;
    signal sprite_tile_reg  : std_logic_vector(7 downto 0);
    signal sprite_attr_reg  : sprite_byte_array_t;
    signal sprite_low_reg   : sprite_byte_array_t;
    signal sprite_high_reg  : sprite_byte_array_t;

    function tile_map_addr(
        x_in       : unsigned(7 downto 0);
        y_in       : unsigned(7 downto 0);
        use_map_1  : std_logic)
        return unsigned is
        variable tile_x_v : unsigned(4 downto 0);
        variable tile_y_v : unsigned(4 downto 0);
        variable base_v   : unsigned(12 downto 0);
        variable addr_v   : unsigned(12 downto 0);
    begin
        tile_x_v := x_in(7 downto 3);
        tile_y_v := y_in(7 downto 3);
        if use_map_1 = '1' then
            base_v := TILE_MAP_1_BASE;
        else
            base_v := TILE_MAP_0_BASE;
        end if;

        addr_v := base_v + resize(tile_y_v & "00000", 13) +
                  resize(tile_x_v, 13);
        return addr_v;
    end function tile_map_addr;

    function tile_data_addr(
        tile_index_in : std_logic_vector(7 downto 0);
        y_in          : unsigned(7 downto 0);
        high_byte_in  : std_logic;
        unsigned_mode_in : std_logic)
        return unsigned is
        variable tile_base_v : unsigned(12 downto 0);
        variable row_base_v  : unsigned(12 downto 0);
        variable addr_v      : unsigned(12 downto 0);
        variable signed_offset_v : signed(12 downto 0);
    begin
        if unsigned_mode_in = '1' then
            tile_base_v := resize(unsigned(tile_index_in), 13) sll 4;
        else
            signed_offset_v := resize(signed(tile_index_in), 13) sll 4;
            tile_base_v := unsigned(signed(TILE_DATA_SIGNED_ZERO_BASE) +
                                    signed_offset_v);
        end if;

        row_base_v := resize(unsigned(y_in(2 downto 0)), 13) sll 1;
        addr_v := tile_base_v + row_base_v;
        if high_byte_in = '1' then
            addr_v := addr_v + 1;
        end if;
        return addr_v;
    end function tile_data_addr;

    function sprite_tile_data_addr(
        tile_index_in : std_logic_vector(7 downto 0);
        sprite_y_in   : std_logic_vector(7 downto 0);
        attr_in       : std_logic_vector(7 downto 0);
        line_in       : unsigned(7 downto 0);
        tall_sprite   : std_logic;
        high_byte_in  : std_logic)
        return unsigned is
        variable tile_index_v : std_logic_vector(7 downto 0);
        variable sprite_row_v : unsigned(8 downto 0);
        variable fetch_row_v  : unsigned(8 downto 0);
        variable addr_v       : unsigned(12 downto 0);
    begin
        if tall_sprite = '1' then
            tile_index_v := tile_index_in(7 downto 1) & '0';
        else
            tile_index_v := tile_index_in;
        end if;

        sprite_row_v := resize(line_in, 9) + to_unsigned(16, 9) -
                        resize(unsigned(sprite_y_in), 9);
        if attr_in(6) = '1' then
            if tall_sprite = '1' then
                fetch_row_v := to_unsigned(15, 9) - sprite_row_v;
            else
                fetch_row_v := to_unsigned(7, 9) - sprite_row_v;
            end if;
        else
            fetch_row_v := sprite_row_v;
        end if;

        if tall_sprite = '1' and fetch_row_v(3) = '1' then
            tile_index_v := std_logic_vector(unsigned(tile_index_v) + 1);
        end if;

        addr_v := (resize(unsigned(tile_index_v), 13) sll 4) +
                  (resize(fetch_row_v(2 downto 0), 13) sll 1);
        if high_byte_in = '1' then
            addr_v := addr_v + 1;
        end if;
        return addr_v;
    end function sprite_tile_data_addr;

    function sprite_candidate_index_at(
        indices_in : std_logic_vector(79 downto 0);
        slot_in    : integer)
        return unsigned is
        variable index_v : unsigned(7 downto 0);
    begin
        case slot_in is
            when 0 =>
                index_v := unsigned(indices_in(7 downto 0));
            when 1 =>
                index_v := unsigned(indices_in(15 downto 8));
            when 2 =>
                index_v := unsigned(indices_in(23 downto 16));
            when 3 =>
                index_v := unsigned(indices_in(31 downto 24));
            when 4 =>
                index_v := unsigned(indices_in(39 downto 32));
            when 5 =>
                index_v := unsigned(indices_in(47 downto 40));
            when 6 =>
                index_v := unsigned(indices_in(55 downto 48));
            when 7 =>
                index_v := unsigned(indices_in(63 downto 56));
            when 8 =>
                index_v := unsigned(indices_in(71 downto 64));
            when others =>
                index_v := unsigned(indices_in(79 downto 72));
        end case;

        return index_v;
    end function sprite_candidate_index_at;

    function pixel_from_tile(
        low_in  : std_logic_vector(7 downto 0);
        high_in : std_logic_vector(7 downto 0);
        x_in    : unsigned(7 downto 0))
        return std_logic_vector is
        variable bit_index_v : integer range 0 to 7;
        variable pixel_v     : std_logic_vector(1 downto 0);
    begin
        bit_index_v := 7 - to_integer(unsigned(x_in(2 downto 0)));
        pixel_v(0) := low_in(bit_index_v);
        pixel_v(1) := high_in(bit_index_v);
        return pixel_v;
    end function pixel_from_tile;

    function apply_bgp_palette(
        color_id_in : std_logic_vector(1 downto 0);
        bgp_in      : std_logic_vector(7 downto 0))
        return std_logic_vector is
        variable shade_v : std_logic_vector(1 downto 0);
    begin
        case color_id_in is
            when "00" =>
                shade_v := bgp_in(1 downto 0);
            when "01" =>
                shade_v := bgp_in(3 downto 2);
            when "10" =>
                shade_v := bgp_in(5 downto 4);
            when others =>
                shade_v := bgp_in(7 downto 6);
        end case;

        return shade_v;
    end function apply_bgp_palette;

    function apply_obj_palette(
        color_id_in : std_logic_vector(1 downto 0);
        palette_in  : std_logic_vector(7 downto 0))
        return std_logic_vector is
        variable shade_v : std_logic_vector(1 downto 0);
    begin
        case color_id_in is
            when "00" =>
                shade_v := palette_in(1 downto 0);
            when "01" =>
                shade_v := palette_in(3 downto 2);
            when "10" =>
                shade_v := palette_in(5 downto 4);
            when others =>
                shade_v := palette_in(7 downto 6);
        end case;

        return shade_v;
    end function apply_obj_palette;

    function sprite_covers_pixel(
        sprite_valid_in : std_logic;
        sprite_x_in     : std_logic_vector(7 downto 0);
        pixel_x_in      : unsigned(7 downto 0))
        return std_logic is
        variable pixel_plus_8_v : unsigned(8 downto 0);
        variable sprite_x_v     : unsigned(8 downto 0);
    begin
        pixel_plus_8_v := resize(pixel_x_in, 9) + to_unsigned(8, 9);
        sprite_x_v := resize(unsigned(sprite_x_in), 9);

        if sprite_valid_in = '1' and
           pixel_plus_8_v >= sprite_x_v and
           pixel_plus_8_v < sprite_x_v + to_unsigned(8, 9) then
            return '1';
        end if;

        return '0';
    end function sprite_covers_pixel;

    function sprite_pixel_from_tile(
        low_in      : std_logic_vector(7 downto 0);
        high_in     : std_logic_vector(7 downto 0);
        sprite_x_in : std_logic_vector(7 downto 0);
        attr_in     : std_logic_vector(7 downto 0);
        pixel_x_in  : unsigned(7 downto 0))
        return std_logic_vector is
        variable sprite_pixel_x_v : unsigned(8 downto 0);
        variable bit_index_v      : integer range 0 to 7;
        variable pixel_v          : std_logic_vector(1 downto 0);
    begin
        sprite_pixel_x_v := resize(pixel_x_in, 9) + to_unsigned(8, 9) -
                            resize(unsigned(sprite_x_in), 9);
        if attr_in(5) = '1' then
            bit_index_v := to_integer(sprite_pixel_x_v(2 downto 0));
        else
            bit_index_v := 7 - to_integer(sprite_pixel_x_v(2 downto 0));
        end if;
        pixel_v(0) := low_in(bit_index_v);
        pixel_v(1) := high_in(bit_index_v);
        return pixel_v;
    end function sprite_pixel_from_tile;

begin

    p_renderer: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' or lcd_enable = '0' then
                state_reg <= S_IDLE;
                pixel_x_reg <= (others => '0');
                pixel_y_reg <= (others => '0');
                dot_count_reg <= (others => '0');
                fb_addr_reg <= (others => '0');
                tile_index_reg <= (others => '0');
                tile_low_reg <= (others => '0');
                tile_high_reg <= (others => '0');
                for i in 0 to MAX_COMPOSE_SPRITES - 1 loop
                    sprite_valid_reg(i) <= '0';
                    sprite_x_reg(i) <= (others => '0');
                    sprite_attr_reg(i) <= (others => '0');
                    sprite_low_reg(i) <= (others => '0');
                    sprite_high_reg(i) <= (others => '0');
                end loop;
                sprite_index_reg <= (others => '0');
                sprite_slot_reg <= 0;
                sprite_y_reg <= (others => '0');
                sprite_tile_reg <= (others => '0');
            else
                case state_reg is
                    when S_IDLE =>
                        pixel_x_reg <= (others => '0');
                        pixel_y_reg <= (others => '0');
                        dot_count_reg <= (others => '0');
                        fb_addr_reg <= (others => '0');
                        if start = '1' then
                            state_reg <= S_MODE2;
                        end if;

                    when S_MODE2 =>
                        if dot_count_reg = to_unsigned(MODE2_DOTS - 1, 9) then
                            pixel_x_reg <= (others => '0');
                            dot_count_reg <= to_unsigned(MODE3_FIRST_DOT, 9);
                            for i in 0 to MAX_COMPOSE_SPRITES - 1 loop
                                sprite_valid_reg(i) <= '0';
                            end loop;
                            sprite_slot_reg <= 0;
                            sprite_index_reg <= sprite_candidate_index_at(
                                sprite_candidate_indices, 0);
                            if lcdc(1) = '1' and sprite_candidate_count /= to_unsigned(0, 4) then
                                state_reg <= S_SPRITE_Y_REQ;
                            else
                                state_reg <= S_MAP_REQ;
                            end if;
                        else
                            dot_count_reg <= dot_count_reg + 1;
                        end if;

                    when S_SPRITE_Y_REQ =>
                        state_reg <= S_SPRITE_Y_CAPTURE;

                    when S_SPRITE_Y_CAPTURE =>
                        sprite_y_reg <= oam_data;
                        state_reg <= S_SPRITE_X_REQ;

                    when S_SPRITE_X_REQ =>
                        state_reg <= S_SPRITE_X_CAPTURE;

                    when S_SPRITE_X_CAPTURE =>
                        sprite_x_reg(sprite_slot_reg) <= oam_data;
                        state_reg <= S_SPRITE_TILE_REQ;

                    when S_SPRITE_TILE_REQ =>
                        state_reg <= S_SPRITE_TILE_CAPTURE;

                    when S_SPRITE_TILE_CAPTURE =>
                        sprite_tile_reg <= oam_data;
                        state_reg <= S_SPRITE_ATTR_REQ;

                    when S_SPRITE_ATTR_REQ =>
                        state_reg <= S_SPRITE_ATTR_CAPTURE;

                    when S_SPRITE_ATTR_CAPTURE =>
                        sprite_attr_reg(sprite_slot_reg) <= oam_data;
                        state_reg <= S_SPRITE_LOW_REQ;

                    when S_SPRITE_LOW_REQ =>
                        state_reg <= S_SPRITE_LOW_CAPTURE;

                    when S_SPRITE_LOW_CAPTURE =>
                        sprite_low_reg(sprite_slot_reg) <= vram_data;
                        state_reg <= S_SPRITE_HIGH_REQ;

                    when S_SPRITE_HIGH_REQ =>
                        state_reg <= S_SPRITE_HIGH_CAPTURE;

                    when S_SPRITE_HIGH_CAPTURE =>
                        sprite_high_reg(sprite_slot_reg) <= vram_data;
                        sprite_valid_reg(sprite_slot_reg) <= '1';
                        if sprite_slot_reg = MAX_COMPOSE_SPRITES - 1 or
                           sprite_candidate_count <= to_unsigned(sprite_slot_reg + 1, 4) then
                            state_reg <= S_MAP_REQ;
                        else
                            sprite_slot_reg <= sprite_slot_reg + 1;
                            sprite_index_reg <= sprite_candidate_index_at(
                                sprite_candidate_indices, sprite_slot_reg + 1);
                            state_reg <= S_SPRITE_Y_REQ;
                        end if;

                    when S_MAP_REQ =>
                        state_reg <= S_MAP_CAPTURE;

                    when S_MAP_CAPTURE =>
                        tile_index_reg <= vram_data;
                        state_reg <= S_TILE_LOW_REQ;

                    when S_TILE_LOW_REQ =>
                        state_reg <= S_TILE_LOW_CAPTURE;

                    when S_TILE_LOW_CAPTURE =>
                        tile_low_reg <= vram_data;
                        state_reg <= S_TILE_HIGH_REQ;

                    when S_TILE_HIGH_REQ =>
                        state_reg <= S_TILE_HIGH_CAPTURE;

                    when S_TILE_HIGH_CAPTURE =>
                        tile_high_reg <= vram_data;
                        state_reg <= S_WRITE_PIXEL;

                    when S_WRITE_PIXEL =>
                        if pixel_x_reg = to_unsigned(SCREEN_WIDTH - 1, 8) then
                            dot_count_reg <= to_unsigned(MODE3_FIRST_DOT + SCREEN_WIDTH, 9);
                            state_reg <= S_MODE3_TAIL;
                        else
                            pixel_x_reg <= pixel_x_reg + 1;
                            dot_count_reg <= dot_count_reg + 1;
                            state_reg <= S_MAP_REQ;
                        end if;
                        fb_addr_reg <= fb_addr_reg + 1;

                    when S_MODE3_TAIL =>
                        if dot_count_reg = to_unsigned(MODE3_LAST_DOT, 9) then
                            dot_count_reg <= to_unsigned(MODE3_LAST_DOT + 1, 9);
                            state_reg <= S_HBLANK;
                        else
                            dot_count_reg <= dot_count_reg + 1;
                        end if;

                    when S_HBLANK =>
                        if dot_count_reg = to_unsigned(DOTS_PER_LINE - 1, 9) then
                            dot_count_reg <= (others => '0');
                            if pixel_y_reg = to_unsigned(SCREEN_HEIGHT - 1, 8) then
                                pixel_y_reg <= to_unsigned(SCREEN_HEIGHT, 8);
                                state_reg <= S_VBLANK;
                            else
                                pixel_y_reg <= pixel_y_reg + 1;
                                state_reg <= S_MODE2;
                            end if;
                        else
                            dot_count_reg <= dot_count_reg + 1;
                        end if;

                    when S_VBLANK =>
                        if dot_count_reg = to_unsigned(DOTS_PER_LINE - 1, 9) then
                            if pixel_y_reg = to_unsigned(VBLANK_LAST_LINE, 8) then
                                state_reg <= S_DONE;
                            else
                                pixel_y_reg <= pixel_y_reg + 1;
                                dot_count_reg <= (others => '0');
                            end if;
                        else
                            dot_count_reg <= dot_count_reg + 1;
                        end if;

                    when S_DONE =>
                        pixel_x_reg <= (others => '0');
                        pixel_y_reg <= (others => '0');
                        dot_count_reg <= (others => '0');
                        fb_addr_reg <= (others => '0');
                        state_reg <= S_MODE2;

                    when others =>
                        state_reg <= S_IDLE;
                end case;
            end if;
        end if;
    end process p_renderer;

    p_outputs: process(state_reg, pixel_x_reg, pixel_y_reg, dot_count_reg, fb_addr_reg,
                       tile_index_reg, tile_low_reg, tile_high_reg,
                       sprite_index_reg, sprite_slot_reg, sprite_valid_reg, sprite_x_reg, sprite_y_reg,
                       sprite_tile_reg, sprite_attr_reg, sprite_low_reg, sprite_high_reg,
                       scroll_x, scroll_y, bgp, obp0, obp1, lcdc)
        variable bg_x_v : unsigned(7 downto 0);
        variable bg_y_v : unsigned(7 downto 0);
        variable color_id_v : std_logic_vector(1 downto 0);
        variable sprite_color_id_v : std_logic_vector(1 downto 0);
        variable shade_v : std_logic_vector(1 downto 0);
        variable sprite_selected_v : std_logic;
    begin
        bg_x_v := pixel_x_reg + unsigned(scroll_x);
        bg_y_v := pixel_y_reg + unsigned(scroll_y);
        color_id_v := pixel_from_tile(tile_low_reg, tile_high_reg, bg_x_v);
        if lcdc(0) = '0' then
            color_id_v := "00";
        end if;
        sprite_color_id_v := "00";
        shade_v := apply_bgp_palette(color_id_v, bgp);
        sprite_selected_v := '0';

        for i in 0 to MAX_COMPOSE_SPRITES - 1 loop
            if sprite_selected_v = '0' and
               sprite_covers_pixel(sprite_valid_reg(i), sprite_x_reg(i), pixel_x_reg) = '1' then
                sprite_color_id_v := sprite_pixel_from_tile(sprite_low_reg(i),
                                                            sprite_high_reg(i),
                                                            sprite_x_reg(i),
                                                            sprite_attr_reg(i),
                                                            pixel_x_reg);
                if sprite_color_id_v /= "00" then
                    if sprite_attr_reg(i)(7) = '0' or color_id_v = "00" then
                        if sprite_attr_reg(i)(4) = '1' then
                            shade_v := apply_obj_palette(sprite_color_id_v, obp1);
                        else
                            shade_v := apply_obj_palette(sprite_color_id_v, obp0);
                        end if;
                        sprite_selected_v := '1';
                    end if;
                end if;
            end if;
        end loop;

        vram_addr <= tile_map_addr(bg_x_v, bg_y_v, lcdc(3));
        oam_addr <= (others => '0');
        oam_read <= '0';
        fb_we <= '0';
        fb_addr <= fb_addr_reg;
        fb_data <= shade_v;
        current_line <= pixel_y_reg;
        current_dot <= dot_count_reg;
        line_active <= '0';
        line_done <= '0';
        ppu_mode <= "00";
        busy <= '0';
        done <= '0';

        case state_reg is
            when S_IDLE =>
                null;
            when S_MODE2 =>
                line_active <= '1';
                ppu_mode <= "10";
                busy <= '1';
            when S_SPRITE_Y_REQ | S_SPRITE_Y_CAPTURE =>
                oam_addr <= resize(sprite_index_reg(5 downto 0), 8) sll 2;
                oam_read <= '1';
                line_active <= '1';
                ppu_mode <= "11";
                busy <= '1';
            when S_SPRITE_X_REQ | S_SPRITE_X_CAPTURE =>
                oam_addr <= (resize(sprite_index_reg(5 downto 0), 8) sll 2) + 1;
                oam_read <= '1';
                line_active <= '1';
                ppu_mode <= "11";
                busy <= '1';
            when S_SPRITE_TILE_REQ | S_SPRITE_TILE_CAPTURE =>
                oam_addr <= (resize(sprite_index_reg(5 downto 0), 8) sll 2) + 2;
                oam_read <= '1';
                line_active <= '1';
                ppu_mode <= "11";
                busy <= '1';
            when S_SPRITE_ATTR_REQ | S_SPRITE_ATTR_CAPTURE =>
                oam_addr <= (resize(sprite_index_reg(5 downto 0), 8) sll 2) + 3;
                oam_read <= '1';
                line_active <= '1';
                ppu_mode <= "11";
                busy <= '1';
            when S_SPRITE_LOW_REQ | S_SPRITE_LOW_CAPTURE =>
                vram_addr <= sprite_tile_data_addr(sprite_tile_reg,
                                                   sprite_y_reg,
                                                   sprite_attr_reg(sprite_slot_reg),
                                                   pixel_y_reg, lcdc(2), '0');
                line_active <= '1';
                ppu_mode <= "11";
                busy <= '1';
            when S_SPRITE_HIGH_REQ | S_SPRITE_HIGH_CAPTURE =>
                vram_addr <= sprite_tile_data_addr(sprite_tile_reg,
                                                   sprite_y_reg,
                                                   sprite_attr_reg(sprite_slot_reg),
                                                   pixel_y_reg, lcdc(2), '1');
                line_active <= '1';
                ppu_mode <= "11";
                busy <= '1';
            when S_MAP_REQ | S_MAP_CAPTURE =>
                vram_addr <= tile_map_addr(bg_x_v, bg_y_v, lcdc(3));
                line_active <= '1';
                ppu_mode <= "11";
                busy <= '1';
            when S_TILE_LOW_REQ | S_TILE_LOW_CAPTURE =>
                vram_addr <= tile_data_addr(tile_index_reg, bg_y_v, '0',
                                            lcdc(4));
                line_active <= '1';
                ppu_mode <= "11";
                busy <= '1';
            when S_TILE_HIGH_REQ | S_TILE_HIGH_CAPTURE =>
                vram_addr <= tile_data_addr(tile_index_reg, bg_y_v, '1',
                                            lcdc(4));
                line_active <= '1';
                ppu_mode <= "11";
                busy <= '1';
            when S_WRITE_PIXEL =>
                fb_we <= '1';
                line_active <= '1';
                ppu_mode <= "11";
                busy <= '1';
            when S_MODE3_TAIL =>
                line_active <= '1';
                ppu_mode <= "11";
                busy <= '1';
            when S_HBLANK =>
                line_active <= '1';
                if dot_count_reg = to_unsigned(DOTS_PER_LINE - 1, 9) then
                    line_done <= '1';
                end if;
                ppu_mode <= "00";
                busy <= '1';
            when S_VBLANK =>
                if dot_count_reg = to_unsigned(DOTS_PER_LINE - 1, 9) then
                    line_done <= '1';
                end if;
                ppu_mode <= "01";
                busy <= '1';
            when S_DONE =>
                ppu_mode <= "01";
                done <= '1';
                busy <= '1';
            when others =>
                null;
        end case;
    end process p_outputs;

end architecture rtl;
