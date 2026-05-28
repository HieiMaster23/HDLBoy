-- =============================================================================
-- Module:      tb_cpu_minimal_vblank_scroll_rom
-- Description: CPU check for VBlank interrupt-driven scroll ROM
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-28
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_cpu_minimal_vblank_scroll_rom is
    generic (
        G_ROM_PATH : string := "../../roms/minimal_vblank_scroll.gb"
    );
end entity tb_cpu_minimal_vblank_scroll_rom;

architecture sim of tb_cpu_minimal_vblank_scroll_rom is

    constant CLK_PERIOD : time := 238 ns;

    type memory_t is array (0 to 65535) of std_logic_vector(7 downto 0);
    type byte_file_t is file of character;

    impure function load_rom(path_in : string) return memory_t is
        file rom_file : byte_file_t open read_mode is path_in;
        variable mem_v : memory_t := (others => x"00");
        variable byte_v : character;
        variable index_v : integer := 0;
    begin
        while not endfile(rom_file) and index_v < 65536 loop
            read(rom_file, byte_v);
            mem_v(index_v) := std_logic_vector(to_unsigned(character'pos(byte_v), 8));
            index_v := index_v + 1;
        end loop;
        report "Loaded ROM bytes: " & integer'image(index_v) severity note;
        return mem_v;
    end function load_rom;

    signal clk : std_logic := '0';
    signal reset : std_logic := '1';
    signal sim_done : boolean := false;

    signal mem_addr : std_logic_vector(15 downto 0);
    signal mem_data_in : std_logic_vector(7 downto 0);
    signal mem_data_out : std_logic_vector(7 downto 0);
    signal mem_read : std_logic;
    signal mem_write : std_logic;
    signal mem_ready : std_logic := '1';
    signal interrupt_ack : std_logic;
    signal interrupt_vector : std_logic_vector(2 downto 0);
    signal interrupt_enable : std_logic_vector(4 downto 0) := (others => '0');
    signal interrupt_flags : std_logic_vector(4 downto 0) := (others => '0');
    signal halted : std_logic;
    signal unsupported_opcode : std_logic;

    signal mem : memory_t := load_rom(G_ROM_PATH);
    signal lcdc_enabled_seen : std_logic := '0';
    signal ie_enabled_seen : std_logic := '0';
    signal halt_seen : std_logic := '0';
    signal scx_update_seen : std_logic := '0';
    signal inject_vblank : std_logic := '0';

begin

    clk <= not clk after CLK_PERIOD / 2 when not sim_done else '0';
    mem_data_in <= mem(to_integer(unsigned(mem_addr)));

    interrupt_enable <= mem(16#FFFF#)(4 downto 0);
    interrupt_flags <= mem(16#FF0F#)(4 downto 0);

    p_memory: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                lcdc_enabled_seen <= '0';
                ie_enabled_seen <= '0';
                halt_seen <= '0';
                scx_update_seen <= '0';
            else
                if inject_vblank = '1' then
                    mem(16#FF0F#)(0) <= '1';
                end if;

                if interrupt_ack = '1' then
                    case interrupt_vector is
                        when "000" =>
                            mem(16#FF0F#)(0) <= '0';
                        when "001" =>
                            mem(16#FF0F#)(1) <= '0';
                        when "010" =>
                            mem(16#FF0F#)(2) <= '0';
                        when "011" =>
                            mem(16#FF0F#)(3) <= '0';
                        when others =>
                            mem(16#FF0F#)(4) <= '0';
                    end case;
                end if;

                if halted = '1' then
                    halt_seen <= '1';
                end if;

                if mem_write = '1' then
                    mem(to_integer(unsigned(mem_addr))) <= mem_data_out;

                    if mem_addr = x"FF40" and mem_data_out = x"91" then
                        lcdc_enabled_seen <= '1';
                    end if;

                    if mem_addr = x"FFFF" and mem_data_out(0) = '1' then
                        ie_enabled_seen <= '1';
                    end if;

                    if mem_addr = x"FF43" and mem_data_out /= x"00" then
                        scx_update_seen <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process p_memory;

    u_cpu: entity work.cpu
        port map (
            clk                => clk,
            reset              => reset,
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
            halted             => halted,
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

    p_stimulus: process
    begin
        report "=== tb_cpu_minimal_vblank_scroll_rom: Starting simulation ===" severity note;
        wait for CLK_PERIOD * 4;
        reset <= '0';

        for i in 0 to 50000 loop
            wait until rising_edge(clk);
            assert unsupported_opcode = '0'
                report "FAIL: unsupported opcode while preparing VBlank ROM"
                severity failure;
            exit when lcdc_enabled_seen = '1' and ie_enabled_seen = '1' and halt_seen = '1';
        end loop;

        assert lcdc_enabled_seen = '1'
            report "FAIL: ROM did not enable LCDC"
            severity failure;
        assert ie_enabled_seen = '1'
            report "FAIL: ROM did not enable VBlank interrupt in IE"
            severity failure;
        assert halt_seen = '1'
            report "FAIL: ROM did not enter HALT loop before VBlank"
            severity failure;

        inject_vblank <= '1';
        wait until rising_edge(clk);
        inject_vblank <= '0';

        for i in 0 to 5000 loop
            wait until rising_edge(clk);
            assert unsupported_opcode = '0'
                report "FAIL: unsupported opcode while servicing VBlank"
                severity failure;
            exit when scx_update_seen = '1';
        end loop;

        assert scx_update_seen = '1'
            report "FAIL: VBlank ISR did not update SCX"
            severity failure;
        assert mem(16#FF43#) = x"01"
            report "FAIL: first VBlank ISR should set SCX to 1"
            severity failure;
        assert mem(16#FF82#) = x"01"
            report "FAIL: VBlank ISR should increment HRAM scroll counter"
            severity failure;

        report "=== tb_cpu_minimal_vblank_scroll_rom: ALL TESTS PASSED ===" severity note;
        sim_done <= true;
        wait;
    end process p_stimulus;

end architecture sim;
