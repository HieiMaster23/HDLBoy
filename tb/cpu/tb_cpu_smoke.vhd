-- =============================================================================
-- Module:      tb_cpu_smoke
-- Description: Small program test for the incremental LR35902 CPU core
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-11
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Program coverage:
--   LD SP,nn; LD HL,nn; LD r,n; LD (HL),r; LD r,(HL);
--   LDH (n),A; LDH A,(n); LD (nn),A; LD A,(nn);
--   ADD/SUB/AND/OR/XOR/CP A,r; ADD/SUB/AND/OR/XOR/CP A,(HL);
--   INC/DEC r; INC/DEC (HL); JP nn; PUSH; POP; CALL; RET; JR e.
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
        16#0011# => x"21", -- LD HL,$C001
        16#0012# => x"01",
        16#0013# => x"C0",
        16#0014# => x"06", -- LD B,$21
        16#0015# => x"21",
        16#0016# => x"70", -- LD (HL),B
        16#0017# => x"21", -- LD HL,$C002
        16#0018# => x"02",
        16#0019# => x"C0",
        16#001A# => x"0E", -- LD C,$22
        16#001B# => x"22",
        16#001C# => x"71", -- LD (HL),C
        16#001D# => x"21", -- LD HL,$C003
        16#001E# => x"03",
        16#001F# => x"C0",
        16#0020# => x"16", -- LD D,$23
        16#0021# => x"23",
        16#0022# => x"72", -- LD (HL),D
        16#0023# => x"21", -- LD HL,$C004
        16#0024# => x"04",
        16#0025# => x"C0",
        16#0026# => x"1E", -- LD E,$24
        16#0027# => x"24",
        16#0028# => x"73", -- LD (HL),E
        16#0029# => x"21", -- LD HL,$C00B
        16#002A# => x"0B",
        16#002B# => x"C0",
        16#002C# => x"74", -- LD (HL),H
        16#002D# => x"21", -- LD HL,$C00C
        16#002E# => x"0C",
        16#002F# => x"C0",
        16#0030# => x"75", -- LD (HL),L
        16#0031# => x"21", -- LD HL,$C007
        16#0032# => x"07",
        16#0033# => x"C0",
        16#0034# => x"3E", -- LD A,$25
        16#0035# => x"25",
        16#0036# => x"77", -- LD (HL),A
        16#0037# => x"21", -- LD HL,$C008
        16#0038# => x"08",
        16#0039# => x"C0",
        16#003A# => x"3E", -- LD A,$C1
        16#003B# => x"C1",
        16#003C# => x"77", -- LD (HL),A
        16#003D# => x"21", -- LD HL,$C009
        16#003E# => x"09",
        16#003F# => x"C0",
        16#0040# => x"3E", -- LD A,$0A
        16#0041# => x"0A",
        16#0042# => x"77", -- LD (HL),A
        16#0043# => x"21", -- LD HL,$C001
        16#0044# => x"01",
        16#0045# => x"C0",
        16#0046# => x"46", -- LD B,(HL)
        16#0047# => x"21", -- LD HL,$C002
        16#0048# => x"02",
        16#0049# => x"C0",
        16#004A# => x"4E", -- LD C,(HL)
        16#004B# => x"21", -- LD HL,$C003
        16#004C# => x"03",
        16#004D# => x"C0",
        16#004E# => x"56", -- LD D,(HL)
        16#004F# => x"21", -- LD HL,$C004
        16#0050# => x"04",
        16#0051# => x"C0",
        16#0052# => x"5E", -- LD E,(HL)
        16#0053# => x"21", -- LD HL,$C007
        16#0054# => x"07",
        16#0055# => x"C0",
        16#0056# => x"7E", -- LD A,(HL)
        16#0057# => x"C3", -- JP $005C
        16#0058# => x"5C",
        16#0059# => x"00",
        16#005A# => x"00",
        16#005B# => x"00",
        16#005C# => x"C5", -- PUSH BC
        16#005D# => x"D1", -- POP DE
        16#005E# => x"CD", -- CALL $0070
        16#005F# => x"70",
        16#0060# => x"00",
        16#0061# => x"00", -- NOP after return
        16#0062# => x"21", -- LD HL,$C008
        16#0063# => x"08",
        16#0064# => x"C0",
        16#0065# => x"66", -- LD H,(HL)
        16#0066# => x"21", -- LD HL,$C009
        16#0067# => x"09",
        16#0068# => x"C0",
        16#0069# => x"6E", -- LD L,(HL)
        16#006A# => x"C3", -- JP $0072
        16#006B# => x"72",
        16#006C# => x"00",
        16#0070# => x"3C", -- INC A -> $26
        16#0071# => x"C9", -- RET
        16#0072# => x"21", -- LD HL,$C00D
        16#0073# => x"0D",
        16#0074# => x"C0",
        16#0075# => x"06", -- LD B,$05
        16#0076# => x"05",
        16#0077# => x"70", -- LD (HL),B
        16#0078# => x"3E", -- LD A,$10
        16#0079# => x"10",
        16#007A# => x"86", -- ADD A,(HL) -> $15
        16#007B# => x"21", -- LD HL,$C00E
        16#007C# => x"0E",
        16#007D# => x"C0",
        16#007E# => x"0E", -- LD C,$03
        16#007F# => x"03",
        16#0080# => x"71", -- LD (HL),C
        16#0081# => x"96", -- SUB (HL) -> $12
        16#0082# => x"21", -- LD HL,$C00F
        16#0083# => x"0F",
        16#0084# => x"C0",
        16#0085# => x"16", -- LD D,$F0
        16#0086# => x"F0",
        16#0087# => x"72", -- LD (HL),D
        16#0088# => x"A6", -- AND (HL) -> $10
        16#0089# => x"21", -- LD HL,$C010
        16#008A# => x"10",
        16#008B# => x"C0",
        16#008C# => x"1E", -- LD E,$0F
        16#008D# => x"0F",
        16#008E# => x"73", -- LD (HL),E
        16#008F# => x"AE", -- XOR (HL) -> $1F
        16#0090# => x"21", -- LD HL,$C011
        16#0091# => x"11",
        16#0092# => x"C0",
        16#0093# => x"06", -- LD B,$80
        16#0094# => x"80",
        16#0095# => x"70", -- LD (HL),B
        16#0096# => x"B6", -- OR (HL) -> $9F
        16#0097# => x"21", -- LD HL,$C012
        16#0098# => x"12",
        16#0099# => x"C0",
        16#009A# => x"0E", -- LD C,$9F
        16#009B# => x"9F",
        16#009C# => x"71", -- LD (HL),C
        16#009D# => x"BE", -- CP (HL), A remains $9F and Z/N are set
        16#009E# => x"21", -- LD HL,$C013
        16#009F# => x"13",
        16#00A0# => x"C0",
        16#00A1# => x"3E", -- LD A,$0F
        16#00A2# => x"0F",
        16#00A3# => x"77", -- LD (HL),A
        16#00A4# => x"34", -- INC (HL) -> $10
        16#00A5# => x"21", -- LD HL,$C014
        16#00A6# => x"14",
        16#00A7# => x"C0",
        16#00A8# => x"3E", -- LD A,$01
        16#00A9# => x"01",
        16#00AA# => x"77", -- LD (HL),A
        16#00AB# => x"35", -- DEC (HL) -> $00
        16#00AC# => x"3E", -- LD A,$42
        16#00AD# => x"42",
        16#00AE# => x"E0", -- LDH ($01),A -> SB
        16#00AF# => x"01",
        16#00B0# => x"3E", -- LD A,$81
        16#00B1# => x"81",
        16#00B2# => x"E0", -- LDH ($02),A -> SC transfer start
        16#00B3# => x"02",
        16#00B4# => x"3E", -- LD A,$55
        16#00B5# => x"55",
        16#00B6# => x"EA", -- LD ($C015),A
        16#00B7# => x"15",
        16#00B8# => x"C0",
        16#00B9# => x"3E", -- LD A,$00
        16#00BA# => x"00",
        16#00BB# => x"FA", -- LD A,($C015)
        16#00BC# => x"15",
        16#00BD# => x"C0",
        16#00BE# => x"F0", -- LDH A,($01)
        16#00BF# => x"01",
        16#00C0# => x"EA", -- LD ($C016),A
        16#00C1# => x"16",
        16#00C2# => x"C0",
        16#00C3# => x"3E", -- LD A,$9F
        16#00C4# => x"9F",
        16#00C5# => x"21", -- LD HL,$C009
        16#00C6# => x"09",
        16#00C7# => x"C0",
        16#00C8# => x"6E", -- LD L,(HL) -> final HL $C00A
        16#00C9# => x"18", -- JR -2
        16#00CA# => x"FE",
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
            mem_ready => '1',
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
        variable saw_h_load : boolean;
    begin
        report "=== tb_cpu_smoke: Starting simulation ===" severity note;
        saw_h_load := false;

        reset <= '1';
        wait for CLK_PERIOD * 4;
        reset <= '0';

        for i in 0 to 720 loop
            wait until rising_edge(clk);
            if debug_pc = x"0066" and debug_h = x"C1" then
                saw_h_load := true;
            end if;
        end loop;

        assert unsupported_opcode = '0'
            report "FAIL: CPU reported unsupported opcode during smoke program"
            severity failure;

        assert mem(16#C000#) = x"12"
            report "FAIL: LD (HL),A did not store the expected byte"
            severity failure;

        assert mem(16#C001#) = x"21" and mem(16#C002#) = x"22" and
               mem(16#C003#) = x"23" and mem(16#C004#) = x"24"
            report "FAIL: LD (HL),r did not store B/C/D/E values correctly"
            severity failure;

        assert mem(16#C00B#) = x"C0" and mem(16#C00C#) = x"0C"
            report "FAIL: LD (HL),H/L did not store the expected HL bytes"
            severity failure;

        assert mem(16#C007#) = x"25" and mem(16#C008#) = x"C1" and
               mem(16#C009#) = x"0A"
            report "FAIL: memory setup for LD r,(HL) checks is incorrect"
            severity failure;

        assert mem(16#C00D#) = x"05" and mem(16#C00E#) = x"03" and
               mem(16#C00F#) = x"F0" and mem(16#C010#) = x"0F" and
               mem(16#C011#) = x"80" and mem(16#C012#) = x"9F"
            report "FAIL: memory setup for ALU A,(HL) checks is incorrect"
            severity failure;

        assert mem(16#C013#) = x"10" and mem(16#C014#) = x"00"
            report "FAIL: INC/DEC (HL) did not write back the expected memory values"
            severity failure;

        assert mem(16#FF01#) = x"42" and mem(16#FF02#) = x"81"
            report "FAIL: LDH (n),A did not update the serial I/O addresses"
            severity failure;

        assert mem(16#C015#) = x"55" and mem(16#C016#) = x"42"
            report "FAIL: LD (nn),A / LD A,(nn) / LDH A,(n) did not transfer expected bytes"
            severity failure;

        assert saw_h_load
            report "FAIL: LD H,(HL) did not load the expected high byte"
            severity failure;

        assert debug_a = x"9F"
            report "FAIL: final A register value is incorrect"
            severity failure;

        assert debug_f = x"C0"
            report "FAIL: final CP (HL) flags are incorrect"
            severity failure;

        assert debug_b = x"80" and debug_c = x"9F"
            report "FAIL: final B/C register values after ALU memory setup are incorrect"
            severity failure;

        assert debug_d = x"F0" and debug_e = x"0F"
            report "FAIL: final D/E register values after ALU memory setup are incorrect"
            severity failure;

        assert debug_h = x"C0" and debug_l = x"0A"
            report "FAIL: final LD L,(HL) result is incorrect"
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
