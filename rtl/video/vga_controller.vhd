-- =============================================================================
-- Module:      vga_controller
-- Description: VGA 640x480@60Hz timing generator with pixel coordinates
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-03-23
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Generates standard VGA 640x480 @ 60Hz sync signals and pixel coordinates.
-- Active-low hsync and vsync per VGA standard.
-- Active-high blanking output indicates when pixel data should be driven.
--
-- Timing (pixel clock = 25.175 MHz):
--   Horizontal: 640 visible + 16 front + 96 sync + 48 back = 800 total
--   Vertical:   480 visible + 10 front +  2 sync + 33 back = 525 total
-- =============================================================================
-- Revision History:
-- 2026-03-23 - Initial creation for M1 milestone
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_controller is
    port (
        -- Clock and reset
        clk_vga   : in  std_logic;  -- 25.175 MHz pixel clock
        reset     : in  std_logic;  -- Synchronous reset, active-high

        -- VGA sync outputs
        hsync     : out std_logic;  -- Horizontal sync (active-low)
        vsync     : out std_logic;  -- Vertical sync (active-low)

        -- Pixel position (valid only when blanking_n = '1')
        pixel_x   : out unsigned(9 downto 0);  -- 0..639 in visible area
        pixel_y   : out unsigned(9 downto 0);  -- 0..479 in visible area

        -- Blanking (active-high = visible, active-low = blanked)
        visible   : out std_logic
    );
end entity vga_controller;

architecture rtl of vga_controller is

    -- Horizontal timing constants
    constant H_VISIBLE : integer := 640;
    constant H_FRONT   : integer := 16;
    constant H_SYNC    : integer := 96;
    constant H_BACK    : integer := 48;
    constant H_TOTAL   : integer := 800;

    -- Vertical timing constants
    constant V_VISIBLE : integer := 480;
    constant V_FRONT   : integer := 10;
    constant V_SYNC    : integer := 2;
    constant V_BACK    : integer := 33;
    constant V_TOTAL   : integer := 525;

    -- Sync pulse start/end positions
    constant H_SYNC_START : integer := H_VISIBLE + H_FRONT;         -- 656
    constant H_SYNC_END   : integer := H_VISIBLE + H_FRONT + H_SYNC; -- 752
    constant V_SYNC_START : integer := V_VISIBLE + V_FRONT;         -- 490
    constant V_SYNC_END   : integer := V_VISIBLE + V_FRONT + V_SYNC; -- 492

    -- Counters (full range including blanking)
    signal h_count : unsigned(9 downto 0);  -- 0..799
    signal v_count : unsigned(9 downto 0);  -- 0..524

begin

    -- Horizontal and vertical counters
    p_counters: process(clk_vga)
    begin
        if rising_edge(clk_vga) then
            if reset = '1' then
                h_count <= (others => '0');
                v_count <= (others => '0');
            else
                if h_count = H_TOTAL - 1 then
                    h_count <= (others => '0');
                    if v_count = V_TOTAL - 1 then
                        v_count <= (others => '0');
                    else
                        v_count <= v_count + 1;
                    end if;
                else
                    h_count <= h_count + 1;
                end if;
            end if;
        end if;
    end process p_counters;

    -- Sync signal generation (active-low per VGA standard)
    p_sync: process(clk_vga)
    begin
        if rising_edge(clk_vga) then
            if reset = '1' then
                hsync <= '1';
                vsync <= '1';
            else
                -- Horizontal sync: low during sync pulse region
                if h_count >= H_SYNC_START and h_count < H_SYNC_END then
                    hsync <= '0';
                else
                    hsync <= '1';
                end if;

                -- Vertical sync: low during sync pulse region
                if v_count >= V_SYNC_START and v_count < V_SYNC_END then
                    vsync <= '0';
                else
                    vsync <= '1';
                end if;
            end if;
        end if;
    end process p_sync;

    -- Pixel coordinates and visible flag
    p_output: process(clk_vga)
    begin
        if rising_edge(clk_vga) then
            if reset = '1' then
                pixel_x <= (others => '0');
                pixel_y <= (others => '0');
                visible <= '0';
            else
                pixel_x <= h_count;
                pixel_y <= v_count;

                if h_count < H_VISIBLE and v_count < V_VISIBLE then
                    visible <= '1';
                else
                    visible <= '0';
                end if;
            end if;
        end if;
    end process p_output;

end architecture rtl;
