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
-- 2026-05-13 - Added first WRAM page, echo mirror, and basic I/O stubs
-- 2026-05-13 - Added serial debug transfer pulse for CPU ROM test output
-- 2026-05-14 - Added registered WRAM/HRAM reads and CPU ready signaling
-- 2026-05-14 - Replaced timer stub with divider-edge DMG timer block
-- 2026-05-16 - Reserved real VRAM at 0x8000..0x9FFF for the future PPU path
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bus_controller is
    generic (
        G_USE_CPU_PPU_DEMO_ROM : boolean := false
    );
    port (
        clk                 : in  std_logic;
        reset               : in  std_logic;

        cpu_addr            : in  std_logic_vector(15 downto 0);
        cpu_data_in         : out std_logic_vector(7 downto 0);
        cpu_data_out        : in  std_logic_vector(7 downto 0);
        cpu_read            : in  std_logic;
        cpu_write           : in  std_logic;
        cpu_ready           : out std_logic;
        unsupported_opcode  : in  std_logic;

        fb_clear_active     : in  std_logic;
        fb_clear_addr       : in  unsigned(14 downto 0);
        fb_we               : out std_logic;
        fb_addr             : out unsigned(14 downto 0);
        fb_data             : out std_logic_vector(1 downto 0);
        ppu_vram_addr       : in  unsigned(12 downto 0);
        ppu_vram_data       : out std_logic_vector(7 downto 0);

        led_pattern         : out std_logic_vector(3 downto 0);
        display_digits      : out std_logic_vector(15 downto 0);
        checker_failed      : out std_logic;
        final_passed        : out std_logic;
        interrupt_ack       : in  std_logic;
        interrupt_vector    : in  std_logic_vector(2 downto 0);
        interrupt_enable    : out std_logic_vector(4 downto 0);
        interrupt_flags     : out std_logic_vector(4 downto 0);
        serial_debug_valid  : out std_logic;
        serial_debug_data   : out std_logic_vector(7 downto 0);
        debug_fb_write_count: out std_logic_vector(7 downto 0)
    );
end entity bus_controller;

architecture rtl of bus_controller is

    constant VRAM_BASE_ADDR     : std_logic_vector(15 downto 0) := x"8000";
    constant VRAM_LAST_ADDR     : std_logic_vector(15 downto 0) := x"9FFF";
    constant FB_BASE_ADDR       : std_logic_vector(15 downto 0) := x"A000";
    constant FB_LAST_ADDR       : std_logic_vector(15 downto 0) := x"BFFF";
    constant WRAM_BASE_ADDR     : std_logic_vector(15 downto 0) := x"C000";
    constant WRAM_LAST_ADDR     : std_logic_vector(15 downto 0) := x"DFFF";
    constant ECHO_BASE_ADDR     : std_logic_vector(15 downto 0) := x"E000";
    constant ECHO_LAST_ADDR     : std_logic_vector(15 downto 0) := x"FDFF";
    constant IO_JOYP_ADDR       : std_logic_vector(15 downto 0) := x"FF00";
    constant IO_SB_ADDR         : std_logic_vector(15 downto 0) := x"FF01";
    constant IO_SC_ADDR         : std_logic_vector(15 downto 0) := x"FF02";
    constant IO_DIV_ADDR        : std_logic_vector(15 downto 0) := x"FF04";
    constant IO_TIMA_ADDR       : std_logic_vector(15 downto 0) := x"FF05";
    constant IO_TMA_ADDR        : std_logic_vector(15 downto 0) := x"FF06";
    constant IO_TAC_ADDR        : std_logic_vector(15 downto 0) := x"FF07";
    constant IO_IF_ADDR         : std_logic_vector(15 downto 0) := x"FF0F";
    constant IO_LCDC_ADDR       : std_logic_vector(15 downto 0) := x"FF40";
    constant IO_STAT_ADDR       : std_logic_vector(15 downto 0) := x"FF41";
    constant IO_SCY_ADDR        : std_logic_vector(15 downto 0) := x"FF42";
    constant IO_SCX_ADDR        : std_logic_vector(15 downto 0) := x"FF43";
    constant IO_LY_ADDR         : std_logic_vector(15 downto 0) := x"FF44";
    constant IO_LYC_ADDR        : std_logic_vector(15 downto 0) := x"FF45";
    constant IO_DMA_ADDR        : std_logic_vector(15 downto 0) := x"FF46";
    constant IO_BGP_ADDR        : std_logic_vector(15 downto 0) := x"FF47";
    constant IO_OBP0_ADDR       : std_logic_vector(15 downto 0) := x"FF48";
    constant IO_OBP1_ADDR       : std_logic_vector(15 downto 0) := x"FF49";
    constant IO_WY_ADDR         : std_logic_vector(15 downto 0) := x"FF4A";
    constant IO_WX_ADDR         : std_logic_vector(15 downto 0) := x"FF4B";
    constant IO_LAST_ADDR       : std_logic_vector(15 downto 0) := x"FF7F";
    constant HRAM_BASE_ADDR     : std_logic_vector(15 downto 0) := x"FF80";
    constant HRAM_LAST_ADDR     : std_logic_vector(15 downto 0) := x"FFFE";
    constant IO_LED_ADDR        : std_logic_vector(15 downto 0) := x"FF80";
    constant IO_STATUS_ADDR     : std_logic_vector(15 downto 0) := x"FF81";
    constant IE_ADDR            : std_logic_vector(15 downto 0) := x"FFFF";
    constant PASS_CODE          : std_logic_vector(7 downto 0)  := x"A5";
    constant EXPECTED_FB_WRITES : unsigned(7 downto 0) := to_unsigned(64, 8);
    constant SMOKE_ROM_LAST_INDEX    : integer := 280;
    constant PPU_DEMO_ROM_LAST_INDEX : integer := 82;
    constant WRAM_LAST_INDEX    : integer := 8191;
    constant HRAM_LAST_INDEX    : integer := 126;

    type smoke_rom_t is array (0 to SMOKE_ROM_LAST_INDEX) of std_logic_vector(7 downto 0);
    type ppu_demo_rom_t is array (0 to PPU_DEMO_ROM_LAST_INDEX) of std_logic_vector(7 downto 0);
    type wram_t is array (0 to WRAM_LAST_INDEX) of std_logic_vector(7 downto 0);
    type hram_t is array (0 to HRAM_LAST_INDEX) of std_logic_vector(7 downto 0);
    constant SMOKE_ROM : smoke_rom_t := (
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

    constant PPU_DEMO_ROM : ppu_demo_rom_t := (
        -- Initialize SP and clear tile 0 at 0x8000..0x800F.
        x"31", x"FE", x"FF", x"21", x"00", x"80", x"AF", x"06",
        x"10", x"22", x"05", x"20", x"FC",
        -- Write tile 1 checkerboard data at 0x8010..0x801F.
        x"21", x"10", x"80", x"3E", x"AA", x"22", x"22", x"3E",
        x"55", x"22", x"22", x"3E", x"AA", x"22", x"22", x"3E",
        x"55", x"22", x"22", x"3E", x"AA", x"22", x"22", x"3E",
        x"55", x"22", x"22", x"3E", x"AA", x"22", x"22", x"3E",
        x"55", x"22", x"22",
        -- Clear the complete 32x32 background map at 0x9800..0x9BFF.
        x"21", x"00", x"98", x"AF", x"06", x"04", x"0E", x"00",
        x"22", x"0D", x"20", x"FC", x"05", x"20", x"F7",
        -- Write an alternating first tile row: tile 1, tile 0, repeated.
        x"21", x"00", x"98", x"06", x"0A", x"3E", x"01", x"22",
        x"AF", x"22", x"05", x"20", x"F8",
        -- Signal completion through debug I/O at 0xFF80, then park forever.
        x"21", x"80", x"FF", x"36", x"01", x"18", x"FE"
    );

    signal io_led_reg        : std_logic_vector(7 downto 0);
    signal io_status_reg     : std_logic_vector(7 downto 0);
    signal joyp_select_reg   : std_logic_vector(1 downto 0);
    signal serial_sb_reg     : std_logic_vector(7 downto 0);
    signal serial_sc_reg     : std_logic_vector(7 downto 0);
    signal serial_debug_valid_reg : std_logic;
    signal serial_debug_data_reg  : std_logic_vector(7 downto 0);
    signal div_read          : std_logic_vector(7 downto 0);
    signal tima_read         : std_logic_vector(7 downto 0);
    signal tma_read          : std_logic_vector(7 downto 0);
    signal tac_read          : std_logic_vector(7 downto 0);
    signal timer_interrupt_set : std_logic;
    signal timer_write_div   : std_logic;
    signal timer_write_tima  : std_logic;
    signal timer_write_tma   : std_logic;
    signal timer_write_tac   : std_logic;
    signal lcdc_reg          : std_logic_vector(7 downto 0);
    signal stat_reg          : std_logic_vector(7 downto 0);
    signal scy_reg           : std_logic_vector(7 downto 0);
    signal scx_reg           : std_logic_vector(7 downto 0);
    signal lyc_reg           : std_logic_vector(7 downto 0);
    signal dma_reg           : std_logic_vector(7 downto 0);
    signal bgp_reg           : std_logic_vector(7 downto 0);
    signal obp0_reg          : std_logic_vector(7 downto 0);
    signal obp1_reg          : std_logic_vector(7 downto 0);
    signal wy_reg            : std_logic_vector(7 downto 0);
    signal wx_reg            : std_logic_vector(7 downto 0);
    signal if_reg            : std_logic_vector(7 downto 0);
    signal ie_reg            : std_logic_vector(7 downto 0);
    signal wram              : wram_t;
    signal hram              : hram_t;
    signal led_pattern_reg   : std_logic_vector(3 downto 0);
    signal fb_write_count    : unsigned(7 downto 0);
    signal checker_failed_reg: std_logic;
    signal final_passed_reg  : std_logic;
    signal vram_selected     : std_logic;
    signal vram_cpu_we       : std_logic;
    signal fb_selected       : std_logic;
    signal wram_selected     : std_logic;
    signal io_selected       : std_logic;
    signal hram_selected     : std_logic;
    signal sync_read_selected: std_logic;
    signal sync_read_valid   : std_logic;
    signal sync_read_addr    : std_logic_vector(15 downto 0);
    signal vram_q            : std_logic_vector(7 downto 0);
    signal wram_q            : std_logic_vector(7 downto 0);
    signal hram_q            : std_logic_vector(7 downto 0);

    function rom_byte(addr_in : std_logic_vector(15 downto 0)) return std_logic_vector is
        variable addr_u : unsigned(15 downto 0);
        variable data_v : std_logic_vector(7 downto 0);
    begin
        addr_u := unsigned(addr_in);
        if G_USE_CPU_PPU_DEMO_ROM then
            if addr_u <= to_unsigned(PPU_DEMO_ROM_LAST_INDEX, 16) then
                data_v := PPU_DEMO_ROM(to_integer(addr_u));
            else
                data_v := x"00";
            end if;
        else
            if addr_u <= to_unsigned(SMOKE_ROM_LAST_INDEX, 16) then
                data_v := SMOKE_ROM(to_integer(addr_u));
            else
                data_v := x"00";
            end if;
        end if;

        return data_v;
    end function rom_byte;

begin

    vram_selected <= '1' when unsigned(cpu_addr) >= unsigned(VRAM_BASE_ADDR) and
                              unsigned(cpu_addr) <= unsigned(VRAM_LAST_ADDR) else '0';
    fb_selected <= '1' when unsigned(cpu_addr) >= unsigned(FB_BASE_ADDR) and
                            unsigned(cpu_addr) <= unsigned(FB_LAST_ADDR) else '0';
    wram_selected <= '1' when (unsigned(cpu_addr) >= unsigned(WRAM_BASE_ADDR) and
                               unsigned(cpu_addr) <= unsigned(WRAM_LAST_ADDR)) or
                              (unsigned(cpu_addr) >= unsigned(ECHO_BASE_ADDR) and
                               unsigned(cpu_addr) <= unsigned(ECHO_LAST_ADDR)) else '0';
    io_selected <= '1' when unsigned(cpu_addr) >= unsigned(IO_JOYP_ADDR) and
                            unsigned(cpu_addr) <= unsigned(IO_LAST_ADDR) else '0';
    hram_selected <= '1' when unsigned(cpu_addr) >= unsigned(HRAM_BASE_ADDR) and
                              unsigned(cpu_addr) <= unsigned(HRAM_LAST_ADDR) else '0';
    sync_read_selected <= '1' when vram_selected = '1' or
                                   wram_selected = '1' or
                                   (hram_selected = '1' and
                                    cpu_addr /= IO_LED_ADDR and
                                    cpu_addr /= IO_STATUS_ADDR) else '0';
    cpu_ready <= '0' when cpu_read = '1' and sync_read_selected = '1' and
                          (sync_read_valid = '0' or sync_read_addr /= cpu_addr) else '1';

    timer_write_div <= '1' when cpu_write = '1' and cpu_addr = IO_DIV_ADDR else '0';
    timer_write_tima <= '1' when cpu_write = '1' and cpu_addr = IO_TIMA_ADDR else '0';
    timer_write_tma <= '1' when cpu_write = '1' and cpu_addr = IO_TMA_ADDR else '0';
    timer_write_tac <= '1' when cpu_write = '1' and cpu_addr = IO_TAC_ADDR else '0';
    vram_cpu_we <= cpu_write and vram_selected;

    u_timer: entity work.timer
        port map (
            clk => clk,
            reset => reset,
            write_data => cpu_data_out,
            write_div => timer_write_div,
            write_tima => timer_write_tima,
            write_tma => timer_write_tma,
            write_tac => timer_write_tac,
            div_read => div_read,
            tima_read => tima_read,
            tma_read => tma_read,
            tac_read => tac_read,
            timer_interrupt_set => timer_interrupt_set
        );

    u_vram: entity work.vram
        port map (
            clk          => clk,
            cpu_we       => vram_cpu_we,
            cpu_addr     => unsigned(cpu_addr(12 downto 0)),
            cpu_data_in  => cpu_data_out,
            cpu_data_out => vram_q,
            ppu_addr     => ppu_vram_addr,
            ppu_data_out => ppu_vram_data
        );

    p_memory_read: process(cpu_addr, cpu_read, io_led_reg, io_status_reg,
                           joyp_select_reg, serial_sb_reg, serial_sc_reg,
                           div_read, tima_read, tma_read, tac_read,
                           lcdc_reg, stat_reg, scy_reg, scx_reg, lyc_reg,
                           dma_reg, bgp_reg, obp0_reg, obp1_reg, wy_reg,
                           wx_reg, if_reg, ie_reg, vram_selected, wram_selected,
                           hram_selected, io_selected, vram_q, wram_q, hram_q)
    begin
        if cpu_read = '1' then
            case cpu_addr is
                when IO_JOYP_ADDR =>
                    cpu_data_in <= "11" & joyp_select_reg & "1111";
                when IO_SB_ADDR =>
                    cpu_data_in <= serial_sb_reg;
                when IO_SC_ADDR =>
                    cpu_data_in <= serial_sc_reg;
                when IO_DIV_ADDR =>
                    cpu_data_in <= div_read;
                when IO_TIMA_ADDR =>
                    cpu_data_in <= tima_read;
                when IO_TMA_ADDR =>
                    cpu_data_in <= tma_read;
                when IO_TAC_ADDR =>
                    cpu_data_in <= tac_read;
                when IO_IF_ADDR =>
                    cpu_data_in <= "111" & if_reg(4 downto 0);
                when IO_LCDC_ADDR =>
                    cpu_data_in <= lcdc_reg;
                when IO_STAT_ADDR =>
                    cpu_data_in <= stat_reg;
                when IO_SCY_ADDR =>
                    cpu_data_in <= scy_reg;
                when IO_SCX_ADDR =>
                    cpu_data_in <= scx_reg;
                when IO_LY_ADDR =>
                    cpu_data_in <= x"00";
                when IO_LYC_ADDR =>
                    cpu_data_in <= lyc_reg;
                when IO_DMA_ADDR =>
                    cpu_data_in <= dma_reg;
                when IO_BGP_ADDR =>
                    cpu_data_in <= bgp_reg;
                when IO_OBP0_ADDR =>
                    cpu_data_in <= obp0_reg;
                when IO_OBP1_ADDR =>
                    cpu_data_in <= obp1_reg;
                when IO_WY_ADDR =>
                    cpu_data_in <= wy_reg;
                when IO_WX_ADDR =>
                    cpu_data_in <= wx_reg;
                when IO_LED_ADDR =>
                    cpu_data_in <= io_led_reg;
                when IO_STATUS_ADDR =>
                    cpu_data_in <= io_status_reg;
                when IE_ADDR =>
                    cpu_data_in <= ie_reg;
                when others =>
                    if vram_selected = '1' then
                        cpu_data_in <= vram_q;
                    elsif wram_selected = '1' then
                        cpu_data_in <= wram_q;
                    elsif io_selected = '1' then
                        cpu_data_in <= x"FF";
                    elsif hram_selected = '1' then
                        cpu_data_in <= hram_q;
                    elsif unsigned(cpu_addr) <= x"7FFF" then
                        cpu_data_in <= rom_byte(cpu_addr);
                    else
                        cpu_data_in <= x"FF";
                    end if;
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
                joyp_select_reg <= "11";
                serial_sb_reg <= (others => '0');
                serial_sc_reg <= x"7E";
                serial_debug_valid_reg <= '0';
                serial_debug_data_reg <= (others => '0');
                lcdc_reg <= x"91";
                stat_reg <= x"80";
                scy_reg <= (others => '0');
                scx_reg <= (others => '0');
                lyc_reg <= (others => '0');
                dma_reg <= x"FF";
                bgp_reg <= x"FC";
                obp0_reg <= x"FF";
                obp1_reg <= x"FF";
                wy_reg <= (others => '0');
                wx_reg <= (others => '0');
                if_reg <= x"E0";
                ie_reg <= (others => '0');
                sync_read_valid <= '0';
                sync_read_addr <= (others => '0');
                fb_write_count <= (others => '0');
                led_pattern_reg <= x"0";
                checker_failed_reg <= '0';
                final_passed_reg <= '0';
            else
                serial_debug_valid_reg <= '0';

                if timer_interrupt_set = '1' then
                    if_reg(2) <= '1';
                end if;

                if interrupt_ack = '1' then
                    case interrupt_vector is
                        when "000" =>
                            if_reg(0) <= '0';
                        when "001" =>
                            if_reg(1) <= '0';
                        when "010" =>
                            if_reg(2) <= '0';
                        when "011" =>
                            if_reg(3) <= '0';
                        when others =>
                            if_reg(4) <= '0';
                    end case;
                end if;

                if cpu_read = '1' and sync_read_selected = '1' then
                    if sync_read_valid = '0' or sync_read_addr /= cpu_addr then
                        sync_read_addr <= cpu_addr;
                        sync_read_valid <= '1';
                    end if;
                else
                    sync_read_valid <= '0';
                end if;

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
                        when IO_JOYP_ADDR =>
                            joyp_select_reg <= cpu_data_out(5 downto 4);
                        when IO_SB_ADDR =>
                            serial_sb_reg <= cpu_data_out;
                        when IO_SC_ADDR =>
                            serial_sc_reg <= cpu_data_out;
                            if cpu_data_out(7) = '1' then
                                serial_debug_valid_reg <= '1';
                                serial_debug_data_reg <= serial_sb_reg;
                            end if;
                        when IO_DIV_ADDR =>
                            null;
                        when IO_TIMA_ADDR =>
                            null;
                        when IO_TMA_ADDR =>
                            null;
                        when IO_TAC_ADDR =>
                            null;
                        when IO_IF_ADDR =>
                            if_reg <= "111" & cpu_data_out(4 downto 0);
                        when IO_LCDC_ADDR =>
                            lcdc_reg <= cpu_data_out;
                        when IO_STAT_ADDR =>
                            stat_reg <= "1" & cpu_data_out(6 downto 3) & "000";
                        when IO_SCY_ADDR =>
                            scy_reg <= cpu_data_out;
                        when IO_SCX_ADDR =>
                            scx_reg <= cpu_data_out;
                        when IO_LY_ADDR =>
                            null;
                        when IO_LYC_ADDR =>
                            lyc_reg <= cpu_data_out;
                        when IO_DMA_ADDR =>
                            dma_reg <= cpu_data_out;
                        when IO_BGP_ADDR =>
                            bgp_reg <= cpu_data_out;
                        when IO_OBP0_ADDR =>
                            obp0_reg <= cpu_data_out;
                        when IO_OBP1_ADDR =>
                            obp1_reg <= cpu_data_out;
                        when IO_WY_ADDR =>
                            wy_reg <= cpu_data_out;
                        when IO_WX_ADDR =>
                            wx_reg <= cpu_data_out;
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
                        when IE_ADDR =>
                            ie_reg <= cpu_data_out;
                        when others =>
                            null;
                    end case;
                end if;
            end if;
        end if;
    end process p_memory_write;

    p_wram: process(clk)
    begin
        if rising_edge(clk) then
            if cpu_write = '1' and wram_selected = '1' then
                wram(to_integer(unsigned(cpu_addr(12 downto 0)))) <= cpu_data_out;
            end if;
            wram_q <= wram(to_integer(unsigned(cpu_addr(12 downto 0))));
        end if;
    end process p_wram;

    p_hram: process(clk)
    begin
        if rising_edge(clk) then
            if cpu_write = '1' and hram_selected = '1' then
                hram(to_integer(unsigned(cpu_addr(6 downto 0)))) <= cpu_data_out;
            end if;
            if hram_selected = '1' then
                hram_q <= hram(to_integer(unsigned(cpu_addr(6 downto 0))));
            else
                hram_q <= x"FF";
            end if;
        end if;
    end process p_hram;

    fb_we   <= '1' when fb_clear_active = '1' else cpu_write and fb_selected;
    fb_addr <= fb_clear_addr when fb_clear_active = '1' else unsigned(cpu_addr(14 downto 0));
    fb_data <= "00" when fb_clear_active = '1' else cpu_data_out(1 downto 0);

    led_pattern <= led_pattern_reg;
    checker_failed <= checker_failed_reg;
    final_passed <= final_passed_reg;
    interrupt_enable <= ie_reg(4 downto 0);
    interrupt_flags <= if_reg(4 downto 0);
    serial_debug_valid <= serial_debug_valid_reg;
    serial_debug_data <= serial_debug_data_reg;
    debug_fb_write_count <= std_logic_vector(fb_write_count);

    display_digits <= x"1234" when final_passed_reg = '1' and checker_failed_reg = '0' else
                      x"EEEE" when checker_failed_reg = '1' else
                      x"0000";

end architecture rtl;
