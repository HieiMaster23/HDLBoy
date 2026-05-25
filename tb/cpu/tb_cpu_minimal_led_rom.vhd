-- =============================================================================
-- Module:      tb_cpu_minimal_led_rom
-- Description: Direct CPU check for the minimal LED ROM bring-up program
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-25
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_cpu_minimal_led_rom is
end entity tb_cpu_minimal_led_rom;

architecture sim of tb_cpu_minimal_led_rom is

    constant CLK_PERIOD : time := 238 ns;

    type memory_t is array (0 to 65535) of std_logic_vector(7 downto 0);

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
    signal debug_a : std_logic_vector(7 downto 0);

    signal led_write_seen : std_logic := '0';
    signal led_write_data : std_logic_vector(7 downto 0) := (others => '0');

    signal mem : memory_t := (
        16#0000# => x"C3", -- JP $0150
        16#0001# => x"50",
        16#0002# => x"01",
        16#0150# => x"F3", -- DI
        16#0151# => x"31", -- LD SP,$DFFE
        16#0152# => x"FE",
        16#0153# => x"DF",
        16#0154# => x"3C", -- INC A -> $01
        16#0155# => x"E0", -- LDH ($80),A
        16#0156# => x"80",
        16#0157# => x"3C", -- INC A x2 -> $03
        16#0158# => x"3C",
        16#0159# => x"E0", -- LDH ($80),A
        16#015A# => x"80",
        16#015B# => x"3C", -- INC A x4 -> $07
        16#015C# => x"3C",
        16#015D# => x"3C",
        16#015E# => x"3C",
        16#015F# => x"E0", -- LDH ($80),A
        16#0160# => x"80",
        16#0161# => x"3C", -- INC A x8 -> $0F
        16#0162# => x"3C",
        16#0163# => x"3C",
        16#0164# => x"3C",
        16#0165# => x"3C",
        16#0166# => x"3C",
        16#0167# => x"3C",
        16#0168# => x"3C",
        16#0169# => x"E0", -- LDH ($80),A
        16#016A# => x"80",
        16#016B# => x"18", -- JR $
        16#016C# => x"FE",
        others => x"00"
    );

begin

    clk <= not clk after CLK_PERIOD / 2 when not sim_done else '0';
    mem_data_in <= mem(to_integer(unsigned(mem_addr)));

    p_capture: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                led_write_seen <= '0';
                led_write_data <= (others => '0');
            elsif mem_write = '1' and mem_addr = x"FF80" then
                led_write_seen <= '1';
                led_write_data <= mem_data_out;
            end if;
        end if;
    end process p_capture;

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
            debug_a            => debug_a,
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
        report "=== tb_cpu_minimal_led_rom: Starting simulation ===" severity note;
        wait for CLK_PERIOD * 4;
        reset <= '0';

        wait for CLK_PERIOD * 80;

        assert unsupported_opcode = '0'
            report "FAIL: unsupported opcode while executing minimal LED ROM"
            severity failure;
        assert led_write_seen = '1'
            report "FAIL: CPU did not write to 0xFF80"
            severity failure;
        assert led_write_data = x"0F"
            report "FAIL: CPU wrote unexpected LED value"
            severity failure;
        assert debug_a = x"0F"
            report "FAIL: register A should hold 0x0F after LED write"
            severity failure;

        report "=== tb_cpu_minimal_led_rom: ALL TESTS PASSED ===" severity note;
        sim_done <= true;
        wait;
    end process p_stimulus;

end architecture sim;
