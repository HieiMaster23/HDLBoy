-- =============================================================================
-- Module:      cpu_ppu_background_demo_top
-- Description: CPU-authored VRAM to PPU background integration demo
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-16
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-16 - Initial CPU -> VRAM -> PPU -> framebuffer integration demo
-- 2026-05-17 - Connected the extracted CPU/PPU demo ROM module
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpu_ppu_background_demo_top is
    port (
        clk_50mhz : in  std_logic;
        reset_n   : in  std_logic;

        vga_r     : out std_logic;
        vga_g     : out std_logic;
        vga_b     : out std_logic;
        vga_hsync : out std_logic;
        vga_vsync : out std_logic;

        led       : out std_logic_vector(3 downto 0)
    );
end entity cpu_ppu_background_demo_top;

architecture rtl of cpu_ppu_background_demo_top is

    signal clk_vga        : std_logic;
    signal clk_cpu        : std_logic;
    signal pll_locked     : std_logic;
    signal pll_areset     : std_logic;
    signal reset_meta     : std_logic;
    signal reset_sync     : std_logic;
    signal reset_cpu      : std_logic;
    signal reset_vga_meta : std_logic;
    signal reset_vga_sync : std_logic;
    signal reset_vga      : std_logic;

    signal mem_addr       : std_logic_vector(15 downto 0);
    signal mem_data_in    : std_logic_vector(7 downto 0);
    signal mem_data_out   : std_logic_vector(7 downto 0);
    signal mem_read       : std_logic;
    signal mem_write      : std_logic;
    signal mem_ready      : std_logic;
    signal rom_data       : std_logic_vector(7 downto 0);

    signal interrupt_ack      : std_logic;
    signal interrupt_vector   : std_logic_vector(2 downto 0);
    signal interrupt_enable   : std_logic_vector(4 downto 0);
    signal interrupt_flags    : std_logic_vector(4 downto 0);
    signal unsupported_opcode : std_logic;

    signal ppu_vram_addr  : unsigned(12 downto 0);
    signal ppu_vram_data  : std_logic_vector(7 downto 0);
    signal ppu_scy        : std_logic_vector(7 downto 0);
    signal ppu_scx        : std_logic_vector(7 downto 0);
    signal ppu_fb_we      : std_logic;
    signal ppu_fb_addr    : unsigned(14 downto 0);
    signal ppu_fb_data    : std_logic_vector(1 downto 0);
    signal ppu_current_line : unsigned(7 downto 0);
    signal ppu_mode       : std_logic_vector(1 downto 0);
    signal ppu_busy       : std_logic;
    signal ppu_done       : std_logic;

    signal led_pattern    : std_logic_vector(3 downto 0);
    signal cpu_vram_ready : std_logic;

    signal fb_addr_b      : unsigned(14 downto 0);
    signal fb_data_b      : std_logic_vector(1 downto 0);

    signal pixel_x        : unsigned(9 downto 0);
    signal pixel_y        : unsigned(9 downto 0);
    signal visible        : std_logic;
    signal hsync_i        : std_logic;
    signal vsync_i        : std_logic;
    signal vga_r_i        : std_logic_vector(2 downto 0);
    signal vga_g_i        : std_logic_vector(2 downto 0);
    signal vga_b_i        : std_logic_vector(2 downto 0);

    signal unused_display_digits : std_logic_vector(15 downto 0);
    signal unused_checker_failed : std_logic;
    signal unused_final_passed   : std_logic;

    function dither_channel(
        level : std_logic_vector(2 downto 0);
        x0    : std_logic;
        y0    : std_logic)
        return std_logic is
    begin
        case level is
            when "111" =>
                return '1';
            when "101" =>
                return x0 or y0;
            when "010" =>
                return x0 and y0;
            when others =>
                return '0';
        end case;
    end function dither_channel;

begin

    pll_areset <= not reset_n;
    cpu_vram_ready <= led_pattern(0);

    u_pll: entity work.pll_core
        port map (
            areset => pll_areset,
            inclk0 => clk_50mhz,
            c0     => clk_vga,
            c1     => clk_cpu,
            locked => pll_locked
        );

    p_cpu_reset_sync: process(clk_cpu)
    begin
        if rising_edge(clk_cpu) then
            reset_meta <= (not reset_n) or (not pll_locked);
            reset_sync <= reset_meta;
        end if;
    end process p_cpu_reset_sync;

    reset_cpu <= reset_sync;

    p_vga_reset_sync: process(clk_vga)
    begin
        if rising_edge(clk_vga) then
            reset_vga_meta <= (not reset_n) or (not pll_locked);
            reset_vga_sync <= reset_vga_meta;
        end if;
    end process p_vga_reset_sync;

    reset_vga <= reset_vga_sync;

    u_cpu: entity work.cpu
        port map (
            clk                => clk_cpu,
            reset              => reset_cpu,
            mem_addr           => mem_addr,
            mem_data_in        => mem_data_in,
            mem_data_out       => mem_data_out,
            mem_read           => mem_read,
            mem_write          => mem_write,
            mem_ready          => mem_ready,
            interrupt_enable   => interrupt_enable,
            interrupt_flags    => interrupt_flags,
            interrupt_ack      => interrupt_ack,
            interrupt_vector   => interrupt_vector,
            halted             => open,
            ime_out            => open,
            interrupt_pending  => open,
            unsupported_opcode => unsupported_opcode,
            debug_a            => open,
            debug_f            => open,
            debug_b            => open,
            debug_c            => open,
            debug_d            => open,
            debug_e            => open,
            debug_h            => open,
            debug_l            => open,
            debug_pc           => open,
            debug_sp           => open,
            debug_state        => open
        );

    u_rom: entity work.cpu_ppu_background_demo_rom
        port map (
            addr => mem_addr,
            data => rom_data
        );

    u_bus: entity work.bus_controller
        port map (
            clk                  => clk_cpu,
            reset                => reset_cpu,
            cpu_addr             => mem_addr,
            cpu_data_in          => mem_data_in,
            cpu_data_out         => mem_data_out,
            cpu_read             => mem_read,
            cpu_write            => mem_write,
            cpu_ready            => mem_ready,
            unsupported_opcode   => unsupported_opcode,
            rom_data             => rom_data,
            fb_clear_active      => '0',
            fb_clear_addr        => (others => '0'),
            fb_we                => open,
            fb_addr              => open,
            fb_data              => open,
            ppu_vram_addr        => ppu_vram_addr,
            ppu_vram_data        => ppu_vram_data,
            ppu_scy              => ppu_scy,
            ppu_scx              => ppu_scx,
            ppu_current_line     => ppu_current_line,
            ppu_mode             => ppu_mode,
            led_pattern          => led_pattern,
            display_digits       => unused_display_digits,
            checker_failed       => unused_checker_failed,
            final_passed         => unused_final_passed,
            interrupt_ack        => interrupt_ack,
            interrupt_vector     => interrupt_vector,
            interrupt_enable     => interrupt_enable,
            interrupt_flags      => interrupt_flags,
            serial_debug_valid   => open,
            serial_debug_data    => open,
            debug_fb_write_count => open
        );

    u_ppu_bg: entity work.ppu_background_renderer
        port map (
            clk       => clk_cpu,
            reset     => reset_cpu,
            start     => cpu_vram_ready,
            scroll_y  => ppu_scy,
            scroll_x  => ppu_scx,
            vram_addr => ppu_vram_addr,
            vram_data => ppu_vram_data,
            fb_we     => ppu_fb_we,
            fb_addr   => ppu_fb_addr,
            fb_data   => ppu_fb_data,
            current_line => ppu_current_line,
            line_active  => open,
            line_done    => open,
            ppu_mode     => ppu_mode,
            busy      => ppu_busy,
            done      => ppu_done
        );

    u_framebuffer: entity work.framebuffer
        port map (
            clk_a  => clk_cpu,
            we_a   => ppu_fb_we,
            addr_a => ppu_fb_addr,
            data_a => ppu_fb_data,
            clk_b  => clk_vga,
            addr_b => fb_addr_b,
            data_b => fb_data_b
        );

    u_vga: entity work.vga_controller
        port map (
            clk_vga => clk_vga,
            reset   => reset_vga,
            hsync   => hsync_i,
            vsync   => vsync_i,
            pixel_x => pixel_x,
            pixel_y => pixel_y,
            visible => visible
        );

    u_pixel_pipe: entity work.vga_pixel_pipeline
        port map (
            clk_vga => clk_vga,
            reset   => reset_vga,
            pixel_x => pixel_x,
            pixel_y => pixel_y,
            visible => visible,
            fb_addr => fb_addr_b,
            fb_data => fb_data_b,
            vga_r   => vga_r_i,
            vga_g   => vga_g_i,
            vga_b   => vga_b_i
        );

    vga_hsync <= hsync_i;
    vga_vsync <= vsync_i;
    vga_r <= dither_channel(vga_r_i, pixel_x(0), pixel_y(0));
    vga_g <= dither_channel(vga_g_i, pixel_x(0), pixel_y(0));
    vga_b <= dither_channel(vga_b_i, pixel_x(0), pixel_y(0));

    led(0) <= not pll_locked;
    led(1) <= not cpu_vram_ready;
    led(2) <= not ppu_done;
    led(3) <= '1';

end architecture rtl;
