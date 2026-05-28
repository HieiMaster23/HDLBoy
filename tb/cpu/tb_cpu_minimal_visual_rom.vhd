-- =============================================================================
-- Module:      tb_cpu_minimal_visual_rom
-- Description: Direct CPU check for the minimal visual SDRAM ROM program
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-27
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_cpu_minimal_visual_rom is
    generic (
        G_ROM_PATH : string := "../../roms/minimal_visual.gb"
    );
end entity tb_cpu_minimal_visual_rom;

architecture sim of tb_cpu_minimal_visual_rom is

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
    signal unsupported_opcode : std_logic;
    signal debug_pc : std_logic_vector(15 downto 0);

    signal mem : memory_t := load_rom(G_ROM_PATH);
    signal lcdc_enabled_seen : std_logic := '0';
    signal vram_write_count : integer range 0 to 2047 := 0;

begin

    clk <= not clk after CLK_PERIOD / 2 when not sim_done else '0';
    mem_data_in <= mem(to_integer(unsigned(mem_addr)));

    p_memory: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                lcdc_enabled_seen <= '0';
                vram_write_count <= 0;
            else
                if mem_write = '1' then
                    mem(to_integer(unsigned(mem_addr))) <= mem_data_out;

                    if unsigned(mem_addr) >= x"8000" and unsigned(mem_addr) <= x"9FFF" then
                        if vram_write_count < 2047 then
                            vram_write_count <= vram_write_count + 1;
                        end if;
                    end if;

                    if mem_addr = x"FF40" and mem_data_out = x"91" then
                        lcdc_enabled_seen <= '1';
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
            interrupt_enable   => "00000",
            interrupt_flags    => "00000",
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
            debug_pc           => debug_pc,
            debug_sp           => open,
            debug_state        => open
        );

    p_stimulus: process
    begin
        report "=== tb_cpu_minimal_visual_rom: Starting simulation ===" severity note;
        wait for CLK_PERIOD * 4;
        reset <= '0';

        for i in 0 to 50000 loop
            wait until rising_edge(clk);
            assert unsupported_opcode = '0'
                report "FAIL: unsupported opcode while executing minimal visual ROM"
                severity failure;
            exit when lcdc_enabled_seen = '1';
        end loop;

        assert lcdc_enabled_seen = '1'
            report "FAIL: CPU did not re-enable LCDC after preparing VRAM"
            severity failure;
        assert vram_write_count >= 1060
            report "FAIL: expected tile data and background map VRAM writes"
            severity failure;

        for i in 0 to 15 loop
            assert mem(16#8000# + i) = x"00"
                report "FAIL: tile 0 should be cleared"
                severity failure;
        end loop;

        assert mem(16#8010#) = x"AA" and mem(16#8011#) = x"AA"
            report "FAIL: tile 1 first row should use 0xAA bytes"
            severity failure;
        assert mem(16#8012#) = x"55" and mem(16#8013#) = x"55"
            report "FAIL: tile 1 second row should use 0x55 bytes"
            severity failure;

        for i in 0 to 9 loop
            assert mem(16#9800# + (i * 2)) = x"01"
                report "FAIL: first background row should contain tile 1 in even columns"
                severity failure;
            assert mem(16#9801# + (i * 2)) = x"00"
                report "FAIL: first background row should contain tile 0 in odd columns"
                severity failure;
        end loop;

        assert mem(16#FF47#) = x"FC"
            report "FAIL: BGP should be configured to 0xFC"
            severity failure;
        assert mem(16#FF42#) = x"01"
            report "FAIL: SCY should be configured to 1"
            severity failure;
        assert mem(16#FF43#) = x"08"
            report "FAIL: SCX should be configured to 8"
            severity failure;
        assert mem(16#FF40#) = x"91"
            report "FAIL: LCDC should be re-enabled with 0x91"
            severity failure;
        report "=== tb_cpu_minimal_visual_rom: ALL TESTS PASSED ===" severity note;
        sim_done <= true;
        wait;
    end process p_stimulus;

end architecture sim;
