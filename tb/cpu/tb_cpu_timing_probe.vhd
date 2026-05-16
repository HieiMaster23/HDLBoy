-- =============================================================================
-- Module:      tb_cpu_timing_probe
-- Description: Small CPU timing probe for representative LR35902 instructions
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-15
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_cpu_timing_probe is
end entity tb_cpu_timing_probe;

architecture sim of tb_cpu_timing_probe is

    constant CLK_PERIOD : time := 238 ns;

    type memory_t is array (0 to 65535) of std_logic_vector(7 downto 0);
    type int_array_t is array (natural range <>) of integer;

    signal clk : std_logic := '0';
    signal reset : std_logic := '1';
    signal mem : memory_t := (
        16#0000# => x"00",       -- NOP
        16#0001# => x"06",       -- LD B,n
        16#0002# => x"12",
        16#0003# => x"01",       -- LD BC,nn
        16#0004# => x"34",
        16#0005# => x"12",
        16#0006# => x"02",       -- LD (BC),A
        16#0007# => x"0A",       -- LD A,(BC)
        16#0008# => x"07",       -- RLCA
        16#0009# => x"08",       -- LD (nn),SP
        16#000A# => x"00",
        16#000B# => x"C0",
        16#000C# => x"27",       -- DAA
        16#000D# => x"2F",       -- CPL
        16#000E# => x"37",       -- SCF
        16#000F# => x"3F",       -- CCF
        16#0010# => x"F3",       -- DI
        16#0011# => x"E0",       -- LDH (n),A
        16#0012# => x"10",
        16#0013# => x"EA",       -- LD (nn),A
        16#0014# => x"00",
        16#0015# => x"C0",
        16#0016# => x"18",       -- JR e
        16#0017# => x"00",
        16#0018# => x"AF",       -- XOR A (sets Z)
        16#0019# => x"20",       -- JR NZ,e (not taken)
        16#001A# => x"00",
        16#001B# => x"28",       -- JR Z,e (taken)
        16#001C# => x"00",
        16#001D# => x"21",       -- LD HL,nn
        16#001E# => x"00",
        16#001F# => x"C0",
        16#0020# => x"34",       -- INC (HL)
        16#0021# => x"35",       -- DEC (HL)
        16#0022# => x"46",       -- LD B,(HL)
        16#0023# => x"70",       -- LD (HL),B
        16#0024# => x"86",       -- ADD A,(HL)
        16#0025# => x"31",       -- LD SP,nn
        16#0026# => x"10",
        16#0027# => x"C0",
        16#0028# => x"C1",       -- POP BC
        16#0029# => x"C5",       -- PUSH BC
        16#002A# => x"AF",       -- XOR A (sets Z)
        16#002B# => x"C2",       -- JP NZ,nn (not taken)
        16#002C# => x"2E",
        16#002D# => x"00",
        16#002E# => x"C4",       -- CALL NZ,nn (not taken)
        16#002F# => x"31",
        16#0030# => x"00",
        16#0031# => x"E8",       -- ADD SP,e
        16#0032# => x"00",
        16#0033# => x"F8",       -- LD HL,SP+e
        16#0034# => x"00",
        16#0035# => x"AF",       -- XOR A (sets Z)
        16#0036# => x"CA",       -- JP Z,nn (taken)
        16#0037# => x"3A",
        16#0038# => x"00",
        16#0039# => x"00",       -- skipped filler
        16#003A# => x"CC",       -- CALL Z,nn (taken)
        16#003B# => x"50",
        16#003C# => x"00",
        16#003D# => x"21",       -- LD HL,nn
        16#003E# => x"43",
        16#003F# => x"00",
        16#0040# => x"E9",       -- JP HL
        16#0041# => x"00",       -- skipped filler
        16#0042# => x"00",       -- skipped filler
        16#0043# => x"FB",       -- EI
        16#0044# => x"CB",       -- RLC B
        16#0045# => x"00",
        16#0046# => x"CB",       -- BIT 0,(HL)
        16#0047# => x"46",
        16#0048# => x"CB",       -- RLC (HL)
        16#0049# => x"06",
        16#004A# => x"C3",       -- JP nn
        16#004B# => x"60",
        16#004C# => x"00",
        16#0050# => x"C8",       -- RET Z (taken)
        16#0060# => x"CD",       -- CALL nn
        16#0061# => x"80",
        16#0062# => x"00",
        16#0063# => x"03",       -- INC BC
        16#0064# => x"0B",       -- DEC BC
        16#0065# => x"21",       -- LD HL,nn
        16#0066# => x"00",
        16#0067# => x"C0",
        16#0068# => x"22",       -- LD (HL+),A
        16#0069# => x"2A",       -- LD A,(HL+)
        16#006A# => x"F0",       -- LDH A,(n)
        16#006B# => x"05",
        16#006C# => x"FA",       -- LD A,(nn)
        16#006D# => x"00",
        16#006E# => x"C0",
        16#006F# => x"F9",       -- LD SP,HL
        16#0070# => x"18",       -- JR e (self loop)
        16#0071# => x"FE",
        16#0080# => x"C9",       -- RET
        others => x"00"
    );

    signal mem_addr : std_logic_vector(15 downto 0);
    signal mem_data_in : std_logic_vector(7 downto 0);
    signal mem_data_out : std_logic_vector(7 downto 0);
    signal mem_read : std_logic;
    signal mem_write : std_logic;
    signal unsupported_opcode : std_logic;
    signal debug_pc : std_logic_vector(15 downto 0);
    signal debug_state : std_logic_vector(4 downto 0);
    signal sim_done : boolean := false;

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

    mem_data_in <= mem(to_integer(unsigned(mem_addr)));

    p_mem_write: process(clk)
    begin
        if rising_edge(clk) then
            if mem_write = '1' then
                mem(to_integer(unsigned(mem_addr))) <= mem_data_out;
            end if;
        end if;
    end process p_mem_write;

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
            interrupt_enable => "00000",
            interrupt_flags => "00000",
            interrupt_ack => open,
            interrupt_vector => open,
            halted => open,
            ime_out => open,
            interrupt_pending => open,
            unsupported_opcode => unsupported_opcode,
            debug_a => open,
            debug_f => open,
            debug_b => open,
            debug_c => open,
            debug_d => open,
            debug_e => open,
            debug_h => open,
            debug_l => open,
            debug_pc => debug_pc,
            debug_sp => open,
            debug_state => debug_state
        );

    p_stimulus: process
        variable cycle_count_v : integer := 0;
        variable fetch_count_v : integer := 0;
        variable fetch_cycle_v : int_array_t(0 to 54) := (others => 0);
    begin
        reset <= '1';
        wait for CLK_PERIOD * 4;
        reset <= '0';

        for i in 0 to 190 loop
            wait until rising_edge(clk);
            cycle_count_v := cycle_count_v + 1;
            if debug_state = "00000" then
                if fetch_count_v <= 54 then
                    fetch_cycle_v(fetch_count_v) := cycle_count_v;
                end if;
                report "FETCH #" & integer'image(fetch_count_v) &
                       " PC=$" & integer'image(to_integer(unsigned(debug_pc))) severity note;
                fetch_count_v := fetch_count_v + 1;
            end if;
        end loop;

        assert unsupported_opcode = '0'
            report "FAIL: unsupported opcode during timing probe"
            severity failure;
        assert fetch_count_v >= 55
            report "FAIL: timing probe did not observe all expected fetches"
            severity failure;
        assert fetch_cycle_v(1) - fetch_cycle_v(0) = 1
            report "FAIL: NOP must consume 1 M-cycle"
            severity failure;
        assert fetch_cycle_v(2) - fetch_cycle_v(1) = 2
            report "FAIL: LD B,n must consume 2 M-cycles"
            severity failure;
        assert fetch_cycle_v(3) - fetch_cycle_v(2) = 3
            report "FAIL: LD BC,nn must consume 3 M-cycles"
            severity failure;
        assert fetch_cycle_v(4) - fetch_cycle_v(3) = 2
            report "FAIL: LD (BC),A must consume 2 M-cycles"
            severity failure;
        assert fetch_cycle_v(5) - fetch_cycle_v(4) = 2
            report "FAIL: LD A,(BC) must consume 2 M-cycles"
            severity failure;
        assert fetch_cycle_v(6) - fetch_cycle_v(5) = 1
            report "FAIL: RLCA must consume 1 M-cycle"
            severity failure;
        assert fetch_cycle_v(7) - fetch_cycle_v(6) = 5
            report "FAIL: LD (nn),SP must consume 5 M-cycles"
            severity failure;
        assert fetch_cycle_v(8) - fetch_cycle_v(7) = 1
            report "FAIL: DAA must consume 1 M-cycle"
            severity failure;
        assert fetch_cycle_v(9) - fetch_cycle_v(8) = 1
            report "FAIL: CPL must consume 1 M-cycle"
            severity failure;
        assert fetch_cycle_v(10) - fetch_cycle_v(9) = 1
            report "FAIL: SCF must consume 1 M-cycle"
            severity failure;
        assert fetch_cycle_v(11) - fetch_cycle_v(10) = 1
            report "FAIL: CCF must consume 1 M-cycle"
            severity failure;
        assert fetch_cycle_v(12) - fetch_cycle_v(11) = 1
            report "FAIL: DI must consume 1 M-cycle"
            severity failure;
        assert fetch_cycle_v(13) - fetch_cycle_v(12) = 3
            report "FAIL: LDH (n),A must consume 3 M-cycles"
            severity failure;
        assert fetch_cycle_v(14) - fetch_cycle_v(13) = 4
            report "FAIL: LD (nn),A must consume 4 M-cycles"
            severity failure;
        assert fetch_cycle_v(15) - fetch_cycle_v(14) = 3
            report "FAIL: JR e must consume 3 M-cycles"
            severity failure;
        assert fetch_cycle_v(16) - fetch_cycle_v(15) = 1
            report "FAIL: XOR A must consume 1 M-cycle"
            severity failure;
        assert fetch_cycle_v(17) - fetch_cycle_v(16) = 2
            report "FAIL: JR NZ,e not taken must consume 2 M-cycles"
            severity failure;
        assert fetch_cycle_v(18) - fetch_cycle_v(17) = 3
            report "FAIL: JR Z,e taken must consume 3 M-cycles"
            severity failure;
        assert fetch_cycle_v(19) - fetch_cycle_v(18) = 3
            report "FAIL: LD HL,nn must consume 3 M-cycles"
            severity failure;
        assert fetch_cycle_v(20) - fetch_cycle_v(19) = 3
            report "FAIL: INC (HL) must consume 3 M-cycles"
            severity failure;
        assert fetch_cycle_v(21) - fetch_cycle_v(20) = 3
            report "FAIL: DEC (HL) must consume 3 M-cycles"
            severity failure;
        assert fetch_cycle_v(22) - fetch_cycle_v(21) = 2
            report "FAIL: LD B,(HL) must consume 2 M-cycles"
            severity failure;
        assert fetch_cycle_v(23) - fetch_cycle_v(22) = 2
            report "FAIL: LD (HL),B must consume 2 M-cycles"
            severity failure;
        assert fetch_cycle_v(24) - fetch_cycle_v(23) = 2
            report "FAIL: ADD A,(HL) must consume 2 M-cycles"
            severity failure;
        assert fetch_cycle_v(25) - fetch_cycle_v(24) = 3
            report "FAIL: LD SP,nn must consume 3 M-cycles"
            severity failure;
        assert fetch_cycle_v(26) - fetch_cycle_v(25) = 3
            report "FAIL: POP BC must consume 3 M-cycles"
            severity failure;
        assert fetch_cycle_v(27) - fetch_cycle_v(26) = 4
            report "FAIL: PUSH BC must consume 4 M-cycles"
            severity failure;
        assert fetch_cycle_v(28) - fetch_cycle_v(27) = 1
            report "FAIL: XOR A must consume 1 M-cycle"
            severity failure;
        assert fetch_cycle_v(29) - fetch_cycle_v(28) = 3
            report "FAIL: JP NZ,nn not taken must consume 3 M-cycles"
            severity failure;
        assert fetch_cycle_v(30) - fetch_cycle_v(29) = 3
            report "FAIL: CALL NZ,nn not taken must consume 3 M-cycles"
            severity failure;
        assert fetch_cycle_v(31) - fetch_cycle_v(30) = 4
            report "FAIL: ADD SP,e must consume 4 M-cycles"
            severity failure;
        assert fetch_cycle_v(32) - fetch_cycle_v(31) = 3
            report "FAIL: LD HL,SP+e must consume 3 M-cycles"
            severity failure;
        assert fetch_cycle_v(33) - fetch_cycle_v(32) = 1
            report "FAIL: XOR A must consume 1 M-cycle"
            severity failure;
        assert fetch_cycle_v(34) - fetch_cycle_v(33) = 4
            report "FAIL: JP Z,nn taken must consume 4 M-cycles"
            severity failure;
        assert fetch_cycle_v(35) - fetch_cycle_v(34) = 6
            report "FAIL: CALL Z,nn taken must consume 6 M-cycles"
            severity failure;
        assert fetch_cycle_v(36) - fetch_cycle_v(35) = 5
            report "FAIL: RET Z taken must consume 5 M-cycles"
            severity failure;
        assert fetch_cycle_v(37) - fetch_cycle_v(36) = 3
            report "FAIL: LD HL,nn must consume 3 M-cycles"
            severity failure;
        assert fetch_cycle_v(38) - fetch_cycle_v(37) = 1
            report "FAIL: JP HL must consume 1 M-cycle"
            severity failure;
        assert fetch_cycle_v(39) - fetch_cycle_v(38) = 1
            report "FAIL: EI must consume 1 M-cycle"
            severity failure;
        assert fetch_cycle_v(40) - fetch_cycle_v(39) = 2
            report "FAIL: CB register opcode must consume 2 M-cycles"
            severity failure;
        assert fetch_cycle_v(41) - fetch_cycle_v(40) = 3
            report "FAIL: CB BIT (HL) must consume 3 M-cycles"
            severity failure;
        assert fetch_cycle_v(42) - fetch_cycle_v(41) = 4
            report "FAIL: CB RMW (HL) must consume 4 M-cycles"
            severity failure;
        assert fetch_cycle_v(43) - fetch_cycle_v(42) = 4
            report "FAIL: JP nn must consume 4 M-cycles"
            severity failure;
        assert fetch_cycle_v(44) - fetch_cycle_v(43) = 6
            report "FAIL: CALL nn must consume 6 M-cycles"
            severity failure;
        assert fetch_cycle_v(45) - fetch_cycle_v(44) = 4
            report "FAIL: RET must consume 4 M-cycles"
            severity failure;
        assert fetch_cycle_v(46) - fetch_cycle_v(45) = 2
            report "FAIL: INC BC must consume 2 M-cycles"
            severity failure;
        assert fetch_cycle_v(47) - fetch_cycle_v(46) = 2
            report "FAIL: DEC BC must consume 2 M-cycles"
            severity failure;
        assert fetch_cycle_v(48) - fetch_cycle_v(47) = 3
            report "FAIL: LD HL,nn must consume 3 M-cycles"
            severity failure;
        assert fetch_cycle_v(49) - fetch_cycle_v(48) = 2
            report "FAIL: LD (HL+),A must consume 2 M-cycles"
            severity failure;
        assert fetch_cycle_v(50) - fetch_cycle_v(49) = 2
            report "FAIL: LD A,(HL+) must consume 2 M-cycles"
            severity failure;
        assert fetch_cycle_v(51) - fetch_cycle_v(50) = 3
            report "FAIL: LDH A,(n) must consume 3 M-cycles"
            severity failure;
        assert fetch_cycle_v(52) - fetch_cycle_v(51) = 4
            report "FAIL: LD A,(nn) must consume 4 M-cycles"
            severity failure;
        assert fetch_cycle_v(53) - fetch_cycle_v(52) = 2
            report "FAIL: LD SP,HL must consume 2 M-cycles"
            severity failure;

        sim_done <= true;
        wait;
    end process p_stimulus;

end architecture sim;
