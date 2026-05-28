-- =============================================================================
-- Module:      sdram_video_rom_top
-- Description: Load-then-execute SDRAM ROM top with CPU, PPU, framebuffer, VGA
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-27
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-27 - Initial SDRAM ROM execution path integrated with video output
-- 2026-05-28 - Start PPU from LCDC enable instead of debug LED marker
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sdram_video_rom_top is
    generic (
        G_INIT_WAIT_CYCLES : natural := 10000;
        G_REFRESH_INTERVAL : natural := 32
    );
    port (
        clk_50mhz   : in    std_logic;
        reset_n     : in    std_logic;
        key_n       : in    std_logic_vector(3 downto 0);
        ps2_clk     : in    std_logic;
        ps2_data    : in    std_logic;

        vga_r       : out   std_logic;
        vga_g       : out   std_logic;
        vga_b       : out   std_logic;
        vga_hsync   : out   std_logic;
        vga_vsync   : out   std_logic;

        led         : out   std_logic_vector(3 downto 0);

        sdram_clk   : out   std_logic;
        sdram_cke   : out   std_logic;
        sdram_cs_n  : out   std_logic;
        sdram_ras_n : out   std_logic;
        sdram_cas_n : out   std_logic;
        sdram_we_n  : out   std_logic;
        sdram_dqm   : out   std_logic_vector(1 downto 0);
        sdram_ba    : out   std_logic_vector(1 downto 0);
        sdram_addr  : out   std_logic_vector(11 downto 0);
        sdram_dq    : inout std_logic_vector(15 downto 0)
    );
end entity sdram_video_rom_top;

architecture rtl of sdram_video_rom_top is

    signal clk_vga              : std_logic;
    signal clk_cpu              : std_logic;
    signal pll_locked           : std_logic;
    signal pll_areset           : std_logic;
    signal reset_meta           : std_logic;
    signal reset_sync           : std_logic;
    signal reset_system         : std_logic;
    signal reset_cpu            : std_logic;
    signal reset_vga_meta       : std_logic;
    signal reset_vga_sync       : std_logic;
    signal reset_vga            : std_logic;

    signal stream_valid         : std_logic;
    signal stream_data          : std_logic_vector(7 downto 0);
    signal stream_ready         : std_logic;
    signal start_pulse          : std_logic;
    signal finish_pulse         : std_logic;
    signal protocol_error       : std_logic;
    signal loader_busy          : std_logic;
    signal loader_done          : std_logic;
    signal loader_error         : std_logic;
    signal cpu_run_reg          : std_logic;
    signal execute_enabled      : std_logic;
    signal fatal_error          : std_logic;
    signal status_led           : std_logic_vector(3 downto 0);

    signal loader_cmd_valid     : std_logic;
    signal loader_cmd_write     : std_logic;
    signal loader_cmd_addr      : unsigned(21 downto 0);
    signal loader_write_data    : std_logic_vector(15 downto 0);
    signal loader_byte_enable   : std_logic_vector(1 downto 0);

    signal reader_cmd_valid     : std_logic;
    signal reader_cmd_write     : std_logic;
    signal reader_cmd_addr      : unsigned(21 downto 0);
    signal reader_write_data    : std_logic_vector(15 downto 0);
    signal reader_byte_enable   : std_logic_vector(1 downto 0);
    signal reader_rom_data      : std_logic_vector(7 downto 0);
    signal reader_rom_ready     : std_logic;

    signal sdram_ready          : std_logic;
    signal sdram_cmd_accept     : std_logic;
    signal sdram_read_valid     : std_logic;
    signal sdram_read_data      : std_logic_vector(15 downto 0);
    signal sdram_init_done      : std_logic;
    signal arb_cmd_valid        : std_logic;
    signal arb_cmd_write        : std_logic;
    signal arb_cmd_addr         : unsigned(21 downto 0);
    signal arb_write_data       : std_logic_vector(15 downto 0);
    signal arb_byte_enable      : std_logic_vector(1 downto 0);

    signal mem_addr             : std_logic_vector(15 downto 0);
    signal mem_data_in          : std_logic_vector(7 downto 0);
    signal mem_data_out         : std_logic_vector(7 downto 0);
    signal mem_read             : std_logic;
    signal mem_write            : std_logic;
    signal mem_ready            : std_logic;
    signal unsupported_opcode   : std_logic;

    signal interrupt_ack        : std_logic;
    signal interrupt_vector     : std_logic_vector(2 downto 0);
    signal interrupt_enable     : std_logic_vector(4 downto 0);
    signal interrupt_flags      : std_logic_vector(4 downto 0);

    signal ppu_vram_addr        : unsigned(12 downto 0);
    signal ppu_vram_data        : std_logic_vector(7 downto 0);
    signal ppu_scy              : std_logic_vector(7 downto 0);
    signal ppu_scx              : std_logic_vector(7 downto 0);
    signal ppu_lcdc             : std_logic_vector(7 downto 0);
    signal ppu_bgp              : std_logic_vector(7 downto 0);
    signal ppu_obp0             : std_logic_vector(7 downto 0);
    signal ppu_obp1             : std_logic_vector(7 downto 0);
    signal ppu_wy               : std_logic_vector(7 downto 0);
    signal ppu_wx               : std_logic_vector(7 downto 0);
    signal ppu_lcd_enable       : std_logic;
    signal ppu_fb_we            : std_logic;
    signal ppu_fb_addr          : unsigned(14 downto 0);
    signal ppu_fb_data          : std_logic_vector(1 downto 0);
    signal ppu_current_line     : unsigned(7 downto 0);
    signal ppu_current_dot      : unsigned(8 downto 0);
    signal ppu_mode             : std_logic_vector(1 downto 0);
    signal ppu_done             : std_logic;
    signal ppu_frame_seen       : std_logic;
    signal ppu_oam_scan_start   : std_logic;
    signal ppu_oam_addr         : unsigned(7 downto 0);
    signal ppu_oam_read         : std_logic;
    signal ppu_oam_data         : std_logic_vector(7 downto 0);
    signal ppu_scan_oam_addr    : unsigned(7 downto 0);
    signal ppu_scan_oam_read    : std_logic;
    signal ppu_render_oam_addr  : unsigned(7 downto 0);
    signal ppu_render_oam_read  : std_logic;
    signal ppu_sprite_count     : unsigned(3 downto 0);
    signal ppu_sprite_indices   : std_logic_vector(79 downto 0);

    signal ps2_btn_right        : std_logic;
    signal ps2_btn_left         : std_logic;
    signal ps2_btn_up           : std_logic;
    signal ps2_btn_down         : std_logic;
    signal ps2_btn_a            : std_logic;
    signal ps2_btn_b            : std_logic;
    signal ps2_btn_select       : std_logic;
    signal ps2_btn_start        : std_logic;
    signal joyp_btn_a           : std_logic;
    signal joyp_btn_b           : std_logic;
    signal joyp_btn_select      : std_logic;
    signal joyp_btn_start       : std_logic;

    signal fb_addr_b            : unsigned(14 downto 0);
    signal fb_data_b            : std_logic_vector(1 downto 0);
    signal pixel_x              : unsigned(9 downto 0);
    signal pixel_y              : unsigned(9 downto 0);
    signal visible              : std_logic;
    signal hsync_i              : std_logic;
    signal vsync_i              : std_logic;
    signal vga_r_i              : std_logic_vector(2 downto 0);
    signal vga_g_i              : std_logic_vector(2 downto 0);
    signal vga_b_i              : std_logic_vector(2 downto 0);

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
    reset_system <= reset_sync;
    reset_cpu <= reset_system or (not cpu_run_reg);
    execute_enabled <= cpu_run_reg;
    fatal_error <= loader_error or protocol_error or unsupported_opcode;
    joyp_btn_a <= (not key_n(0)) or ps2_btn_a;
    joyp_btn_b <= (not key_n(1)) or ps2_btn_b;
    joyp_btn_select <= (not key_n(2)) or ps2_btn_select;
    joyp_btn_start <= (not key_n(3)) or ps2_btn_start;

    p_cpu_run_control: process(clk_cpu)
    begin
        if rising_edge(clk_cpu) then
            if reset_system = '1' then
                cpu_run_reg <= '0';
            else
                if start_pulse = '1' or loader_error = '1' or protocol_error = '1' then
                    cpu_run_reg <= '0';
                elsif loader_done = '1' and sdram_init_done = '1' then
                    cpu_run_reg <= '1';
                end if;
            end if;
        end if;
    end process p_cpu_run_control;

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

    p_vga_reset_sync: process(clk_vga)
    begin
        if rising_edge(clk_vga) then
            reset_vga_meta <= (not reset_n) or (not pll_locked);
            reset_vga_sync <= reset_vga_meta;
        end if;
    end process p_vga_reset_sync;

    reset_vga <= reset_vga_sync;

    p_ppu_frame_seen: process(clk_cpu)
    begin
        if rising_edge(clk_cpu) then
            if reset_cpu = '1' then
                ppu_frame_seen <= '0';
            elsif ppu_done = '1' then
                ppu_frame_seen <= '1';
            end if;
        end if;
    end process p_ppu_frame_seen;

    u_jtag_stream: entity work.virtual_jtag_rom_stream
        port map (
            clk             => clk_cpu,
            reset           => reset_system,
            stream_valid    => stream_valid,
            stream_data     => stream_data,
            stream_ready    => stream_ready,
            start_pulse     => start_pulse,
            finish_pulse    => finish_pulse,
            protocol_error  => protocol_error,
            loader_busy     => loader_busy,
            loader_done     => loader_done,
            loader_error    => loader_error,
            sdram_init_done => sdram_init_done
        );

    u_loader: entity work.sdram_rom_loader
        generic map (
            G_ADDR_WIDTH => 22
        )
        port map (
            clk               => clk_cpu,
            reset             => reset_system,
            start             => start_pulse,
            finish            => finish_pulse,
            stream_valid      => stream_valid,
            stream_data       => stream_data,
            stream_ready      => stream_ready,
            busy              => loader_busy,
            done              => loader_done,
            error             => loader_error,
            loaded_words      => open,
            sdram_ready       => sdram_ready,
            sdram_cmd_accept  => sdram_cmd_accept,
            sdram_cmd_valid   => loader_cmd_valid,
            sdram_cmd_write   => loader_cmd_write,
            sdram_cmd_addr    => loader_cmd_addr,
            sdram_write_data  => loader_write_data,
            sdram_byte_enable => loader_byte_enable
        );

    u_rom_reader: entity work.sdram_rom_reader
        generic map (
            G_ADDR_WIDTH => 22
        )
        port map (
            clk               => clk_cpu,
            reset             => reset_cpu,
            cpu_addr          => mem_addr,
            cpu_read          => mem_read,
            rom_data          => reader_rom_data,
            rom_ready         => reader_rom_ready,
            sdram_ready       => sdram_ready,
            sdram_cmd_accept  => sdram_cmd_accept,
            sdram_read_valid  => sdram_read_valid,
            sdram_read_data   => sdram_read_data,
            sdram_cmd_valid   => reader_cmd_valid,
            sdram_cmd_write   => reader_cmd_write,
            sdram_cmd_addr    => reader_cmd_addr,
            sdram_write_data  => reader_write_data,
            sdram_byte_enable => reader_byte_enable
        );

    arb_cmd_valid <= reader_cmd_valid when execute_enabled = '1' else loader_cmd_valid;
    arb_cmd_write <= reader_cmd_write when execute_enabled = '1' else loader_cmd_write;
    arb_cmd_addr <= reader_cmd_addr when execute_enabled = '1' else loader_cmd_addr;
    arb_write_data <= reader_write_data when execute_enabled = '1' else loader_write_data;
    arb_byte_enable <= reader_byte_enable when execute_enabled = '1' else loader_byte_enable;

    u_sdram: entity work.sdram_controller
        generic map (
            G_INIT_WAIT_CYCLES   => G_INIT_WAIT_CYCLES,
            G_REFRESH_INTERVAL   => G_REFRESH_INTERVAL,
            G_TRP_CYCLES         => 2,
            G_TRCD_CYCLES        => 2,
            G_TRC_CYCLES         => 4,
            G_TWR_CYCLES         => 2,
            G_TMRD_CYCLES        => 2,
            G_CAS_LATENCY_CYCLES => 2
        )
        port map (
            clk           => clk_cpu,
            reset         => reset_system,
            cmd_valid     => arb_cmd_valid,
            cmd_write     => arb_cmd_write,
            cmd_addr      => arb_cmd_addr,
            write_data    => arb_write_data,
            byte_enable   => arb_byte_enable,
            ready         => sdram_ready,
            cmd_accept    => sdram_cmd_accept,
            read_valid    => sdram_read_valid,
            read_data     => sdram_read_data,
            init_done     => sdram_init_done,
            refresh_pulse => open,
            sdram_clk     => sdram_clk,
            sdram_cke     => sdram_cke,
            sdram_cs_n    => sdram_cs_n,
            sdram_ras_n   => sdram_ras_n,
            sdram_cas_n   => sdram_cas_n,
            sdram_we_n    => sdram_we_n,
            sdram_dqm     => sdram_dqm,
            sdram_ba      => sdram_ba,
            sdram_addr    => sdram_addr,
            sdram_dq      => sdram_dq
        );

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

    u_ps2_joypad: entity work.ps2_keyboard_joypad
        port map (
            clk        => clk_cpu,
            reset      => reset_cpu,
            ps2_clk    => ps2_clk,
            ps2_data   => ps2_data,
            btn_right  => ps2_btn_right,
            btn_left   => ps2_btn_left,
            btn_up     => ps2_btn_up,
            btn_down   => ps2_btn_down,
            btn_a      => ps2_btn_a,
            btn_b      => ps2_btn_b,
            btn_select => ps2_btn_select,
            btn_start  => ps2_btn_start
        );

    u_bus: entity work.bus_controller
        generic map (
            G_ENABLE_FB_WINDOW     => false,
            G_ENABLE_SMOKE_CHECKER => false,
            G_ENABLE_SERIAL_DEBUG  => false
        )
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
            rom_data             => reader_rom_data,
            rom_ready            => reader_rom_ready,
            btn_right            => ps2_btn_right,
            btn_left             => ps2_btn_left,
            btn_up               => ps2_btn_up,
            btn_down             => ps2_btn_down,
            btn_a                => joyp_btn_a,
            btn_b                => joyp_btn_b,
            btn_select           => joyp_btn_select,
            btn_start            => joyp_btn_start,
            fb_clear_active      => '0',
            fb_clear_addr        => (others => '0'),
            fb_we                => open,
            fb_addr              => open,
            fb_data              => open,
            ppu_vram_addr        => ppu_vram_addr,
            ppu_vram_data        => ppu_vram_data,
            ppu_scy              => ppu_scy,
            ppu_scx              => ppu_scx,
            ppu_lcdc             => ppu_lcdc,
            ppu_bgp              => ppu_bgp,
            ppu_obp0             => ppu_obp0,
            ppu_obp1             => ppu_obp1,
            ppu_wy               => ppu_wy,
            ppu_wx               => ppu_wx,
            ppu_lcd_enable       => ppu_lcd_enable,
            ppu_oam_addr         => ppu_oam_addr,
            ppu_oam_read         => ppu_oam_read,
            ppu_oam_data         => ppu_oam_data,
            ppu_current_line     => ppu_current_line,
            ppu_mode             => ppu_mode,
            led_pattern          => open,
            display_digits       => open,
            checker_failed       => open,
            final_passed         => open,
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
            start     => ppu_lcd_enable,
            lcd_enable => ppu_lcd_enable,
            lcdc      => ppu_lcdc,
            scroll_y  => ppu_scy,
            scroll_x  => ppu_scx,
            window_y  => ppu_wy,
            window_x  => ppu_wx,
            bgp       => ppu_bgp,
            obp0      => ppu_obp0,
            obp1      => ppu_obp1,
            sprite_candidate_count   => ppu_sprite_count,
            sprite_candidate_indices => ppu_sprite_indices,
            vram_addr => ppu_vram_addr,
            vram_data => ppu_vram_data,
            oam_addr  => ppu_render_oam_addr,
            oam_read  => ppu_render_oam_read,
            oam_data  => ppu_oam_data,
            fb_we     => ppu_fb_we,
            fb_addr   => ppu_fb_addr,
            fb_data   => ppu_fb_data,
            current_line => ppu_current_line,
            current_dot  => ppu_current_dot,
            line_active  => open,
            line_done    => open,
            ppu_mode     => ppu_mode,
            busy      => open,
            done      => ppu_done
        );

    ppu_oam_scan_start <= '1' when ppu_mode = "10" and
                                   ppu_current_dot = to_unsigned(0, 9) else '0';
    ppu_oam_addr <= ppu_scan_oam_addr when ppu_scan_oam_read = '1' else
                    ppu_render_oam_addr;
    ppu_oam_read <= ppu_scan_oam_read or ppu_render_oam_read;

    u_ppu_oam_scan: entity work.ppu_oam_scan
        port map (
            clk               => clk_cpu,
            reset             => reset_cpu,
            start             => ppu_oam_scan_start,
            current_line      => ppu_current_line,
            lcdc              => ppu_lcdc,
            oam_addr          => ppu_scan_oam_addr,
            oam_read          => ppu_scan_oam_read,
            oam_data          => ppu_oam_data,
            candidate_count   => ppu_sprite_count,
            candidate_indices => ppu_sprite_indices,
            busy              => open,
            done              => open
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

    status_led(0) <= not sdram_init_done;
    status_led(1) <= not loader_done;
    status_led(2) <= not execute_enabled;
    status_led(3) <= not fatal_error;

    led <= status_led when execute_enabled = '0' or fatal_error = '1' else
           not (ppu_frame_seen & ppu_lcd_enable & loader_done & sdram_init_done);

end architecture rtl;
