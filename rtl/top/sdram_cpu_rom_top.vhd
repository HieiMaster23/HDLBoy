-- =============================================================================
-- Module:      sdram_cpu_rom_top
-- Description: CPU execution top using ROM bytes previously loaded into SDRAM
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-25
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-25 - Initial load-then-execute SDRAM ROM top
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sdram_cpu_rom_top is
    generic (
        G_INIT_WAIT_CYCLES : natural := 10000;
        G_REFRESH_INTERVAL : natural := 32
    );
    port (
        clk_50mhz   : in    std_logic;
        reset_n     : in    std_logic;
        key_n       : in    std_logic_vector(3 downto 0);

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
end entity sdram_cpu_rom_top;

architecture rtl of sdram_cpu_rom_top is

    signal clk_cpu              : std_logic;
    signal pll_locked           : std_logic;
    signal pll_areset           : std_logic;
    signal reset_meta           : std_logic;
    signal reset_sync           : std_logic;
    signal reset_system         : std_logic;
    signal reset_cpu            : std_logic;

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
    signal led_write_count      : unsigned(3 downto 0);
    signal fetch_checkpoint     : std_logic_vector(3 downto 0);
    signal execution_summary    : std_logic_vector(3 downto 0);

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
    signal debug_a              : std_logic_vector(7 downto 0);

begin

    pll_areset <= not reset_n;
    reset_system <= reset_sync;
    reset_cpu <= reset_system or (not cpu_run_reg);
    execute_enabled <= cpu_run_reg;
    fatal_error <= loader_error or protocol_error or unsupported_opcode;

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

    p_execution_debug: process(clk_cpu)
    begin
        if rising_edge(clk_cpu) then
            if reset_system = '1' or start_pulse = '1' then
                led_write_count <= (others => '0');
                fetch_checkpoint <= (others => '0');
            else
                if execute_enabled = '1' and mem_read = '1' and mem_ready = '1' then
                    if mem_addr = x"0000" and mem_data_in = x"C3" then
                        fetch_checkpoint(0) <= '1';
                    end if;
                    if mem_addr = x"0150" and mem_data_in = x"F3" then
                        fetch_checkpoint(1) <= '1';
                    end if;
                    if mem_addr = x"0154" and mem_data_in = x"3C" then
                        fetch_checkpoint(2) <= '1';
                    end if;
                    if mem_addr = x"0169" and mem_data_in = x"E0" then
                        fetch_checkpoint(3) <= '1';
                    end if;
                end if;

                if execute_enabled = '1' and mem_write = '1' and mem_addr = x"FF80" then
                    if led_write_count /= x"F" then
                        led_write_count <= led_write_count + 1;
                    end if;
                end if;
            end if;
        end if;
    end process p_execution_debug;

    u_pll: entity work.pll_core
        port map (
            areset => pll_areset,
            inclk0 => clk_50mhz,
            c0     => open,
            c1     => clk_cpu,
            locked => pll_locked
        );

    p_reset_sync: process(clk_cpu)
    begin
        if rising_edge(clk_cpu) then
            reset_meta <= (not reset_n) or (not pll_locked);
            reset_sync <= reset_meta;
        end if;
    end process p_reset_sync;

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
            debug_a            => debug_a,
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
            btn_right            => '0',
            btn_left             => '0',
            btn_up               => '0',
            btn_down             => '0',
            btn_a                => not key_n(0),
            btn_b                => not key_n(1),
            btn_select           => not key_n(2),
            btn_start            => not key_n(3),
            fb_clear_active      => '0',
            fb_clear_addr        => (others => '0'),
            fb_we                => open,
            fb_addr              => open,
            fb_data              => open,
            ppu_vram_addr        => (others => '0'),
            ppu_vram_data        => open,
            ppu_scy              => open,
            ppu_scx              => open,
            ppu_lcdc             => open,
            ppu_bgp              => open,
            ppu_obp0             => open,
            ppu_obp1             => open,
            ppu_wy               => open,
            ppu_wx               => open,
            ppu_lcd_enable       => open,
            ppu_oam_addr         => (others => '0'),
            ppu_oam_read         => '0',
            ppu_oam_data         => open,
            ppu_current_line     => (others => '0'),
            ppu_mode             => "00",
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

    -- During load, LEDs show loader status. During execution, expose a compact
    -- pass/fail summary so board bring-up does not depend on button ordering.
    status_led(0) <= not sdram_init_done;
    status_led(1) <= not loader_busy;
    status_led(2) <= not loader_done;
    status_led(3) <= not fatal_error;

    execution_summary(0) <= fetch_checkpoint(3);
    execution_summary(1) <= '1' when led_write_count >= x"4" else '0';
    execution_summary(2) <= '1' when debug_a(3 downto 0) = x"F" else '0';
    execution_summary(3) <= not fatal_error;

    led <= not execution_summary when execute_enabled = '1' else
           "1010" when execute_enabled = '1' and fatal_error = '0' else
           status_led;

end architecture rtl;
