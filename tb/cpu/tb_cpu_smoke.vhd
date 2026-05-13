-- =============================================================================
-- Module:      tb_cpu_smoke
-- Description: Small program test for the incremental LR35902 CPU core
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-11
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Program coverage:
--   LD SP,nn; LD HL,nn; LD r,n; LD (HL),A; LD A,(HL);
--   ADD A,r; DEC r; SUB r; JP nn; PUSH; POP; CALL; RET; JR e.
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_cpu_smoke is
end entity tb_cpu_smoke;

architecture sim of tb_cpu_smoke is

    constant CLK_PERIOD : time := 238 ns; -- Approximately 4.194 MHz

    type memory_t is array (0 to 65535) of std_logic_vector(7 downto 0);

    signal clk : std_logic := '0';
    signal reset : std_logic := '1';
    signal sim_done : boolean := false;

    signal mem_addr : std_logic_vector(15 downto 0);
    signal mem_data_in : std_logic_vector(7 downto 0);
    signal mem_data_out : std_logic_vector(7 downto 0);
    signal mem_read : std_logic;
    signal mem_write : std_logic;
    signal interrupt_enable : std_logic_vector(4 downto 0) := "00000";
    signal interrupt_flags : std_logic_vector(4 downto 0) := "00000";
    signal interrupt_ack : std_logic;
    signal interrupt_vector : std_logic_vector(2 downto 0);
    signal halted : std_logic;
    signal ime_out : std_logic;
    signal interrupt_pending : std_logic;
    signal unsupported_opcode : std_logic;
    signal debug_a : std_logic_vector(7 downto 0);
    signal debug_f : std_logic_vector(7 downto 0);
    signal debug_b : std_logic_vector(7 downto 0);
    signal debug_c : std_logic_vector(7 downto 0);
    signal debug_d : std_logic_vector(7 downto 0);
    signal debug_e : std_logic_vector(7 downto 0);
    signal debug_h : std_logic_vector(7 downto 0);
    signal debug_l : std_logic_vector(7 downto 0);
    signal debug_pc : std_logic_vector(15 downto 0);
    signal debug_sp : std_logic_vector(15 downto 0);
    signal debug_state : std_logic_vector(4 downto 0);

    signal mem : memory_t := (
        16#0000# => x"31", -- LD SP,$FFFE
        16#0001# => x"FE",
        16#0002# => x"FF",
        16#0003# => x"21", -- LD HL,$C000
        16#0004# => x"00",
        16#0005# => x"C0",
        16#0006# => x"3E", -- LD A,$12
        16#0007# => x"12",
        16#0008# => x"77", -- LD (HL),A
        16#0009# => x"3E", -- LD A,$00
        16#000A# => x"00",
        16#000B# => x"7E", -- LD A,(HL)
        16#000C# => x"06", -- LD B,$03
        16#000D# => x"03",
        16#000E# => x"80", -- ADD A,B -> $15
        16#000F# => x"05", -- DEC B -> $02
        16#0010# => x"90", -- SUB B -> $13
        16#0011# => x"C3", -- JP $0016
        16#0012# => x"16",
        16#0013# => x"00",
        16#0014# => x"00",
        16#0015# => x"00",
        16#0016# => x"C5", -- PUSH BC
        16#0017# => x"D1", -- POP DE
        16#0018# => x"CD", -- CALL $0020
        16#0019# => x"20",
        16#001A# => x"00",
        16#001B# => x"00", -- NOP after return
        16#001C# => x"18", -- JR -2
        16#001D# => x"FE",
        16#0020# => x"3C", -- INC A -> $14
        16#0021# => x"C9", -- RET
        others => x"00"
    );

begin

    p_clk: process
    begin
        while not sim_done loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process p_clk;

    u_dut: entity work.cpu
        port map (
            clk => clk,
            reset => reset,
            mem_addr => mem_addr,
            mem_data_in => mem_data_in,
            mem_data_out => mem_data_out,
            mem_read => mem_read,
            mem_write => mem_write,
            interrupt_enable => interrupt_enable,
            interrupt_flags => interrupt_flags,
            interrupt_ack => interrupt_ack,
            interrupt_vector => interrupt_vector,
            halted => halted,
            ime_out => ime_out,
            interrupt_pending => interrupt_pending,
            unsupported_opcode => unsupported_opcode,
            debug_a => debug_a,
            debug_f => debug_f,
            debug_b => debug_b,
            debug_c => debug_c,
            debug_d => debug_d,
            debug_e => debug_e,
            debug_h => debug_h,
            debug_l => debug_l,
            debug_pc => debug_pc,
            debug_sp => debug_sp,
            debug_state => debug_state
        );

    mem_data_in <= mem(to_integer(unsigned(mem_addr)));

    p_memory_write: process(clk)
    begin
        if rising_edge(clk) then
            if mem_write = '1' then
                mem(to_integer(unsigned(mem_addr))) <= mem_data_out;
            end if;
        end if;
    end process p_memory_write;

    p_stimulus: process
    begin
        report "=== tb_cpu_smoke: Starting simulation ===" severity note;

        reset <= '1';
        wait for CLK_PERIOD * 4;
        reset <= '0';

        wait for CLK_PERIOD * 160;

        assert unsupported_opcode = '0'
            report "FAIL: CPU reported unsupported opcode during smoke program"
            severity failure;

        assert mem(16#C000#) = x"12"
            report "FAIL: LD (HL),A did not store the expected byte"
            severity failure;

        assert debug_a = x"14"
            report "FAIL: final A register value is incorrect"
            severity failure;

        assert debug_b = x"02" and debug_c = x"00"
            report "FAIL: BC register value after arithmetic is incorrect"
            severity failure;

        assert debug_d = x"02" and debug_e = x"00"
            report "FAIL: PUSH BC / POP DE did not transfer the expected pair"
            severity failure;

        assert debug_h = x"C0" and debug_l = x"00"
            report "FAIL: HL register value is incorrect"
            severity failure;

        assert debug_sp = x"FFFE"
            report "FAIL: stack pointer did not return to its initial value"
            severity failure;

        assert halted = '0'
            report "FAIL: CPU halted unexpectedly"
            severity failure;

        report "=== tb_cpu_smoke: ALL TESTS PASSED ===" severity note;
        sim_done <= true;
        wait;
    end process p_stimulus;

end architecture sim;
