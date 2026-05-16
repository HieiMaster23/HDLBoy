-- =============================================================================
-- Module:      tb_cpu_timer_blargg_probe
-- Description: CPU plus timer probe for Blargg-style TIMA synchronization loops
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-16
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_cpu_timer_blargg_probe is
    generic (
        G_TIMER_DIV_RESET : integer := 4
    );
end entity tb_cpu_timer_blargg_probe;

architecture sim of tb_cpu_timer_blargg_probe is

    constant CLK_PERIOD   : time := 238 ns;
    constant IO_TIMA_ADDR : std_logic_vector(15 downto 0) := x"FF05";
    constant IO_TMA_ADDR  : std_logic_vector(15 downto 0) := x"FF06";
    constant IO_TAC_ADDR  : std_logic_vector(15 downto 0) := x"FF07";
    constant RESULT_NOP_ADDR   : std_logic_vector(15 downto 0) := x"C000";
    constant RESULT_LD_BC_ADDR : std_logic_vector(15 downto 0) := x"C001";
    constant MAX_CYCLES   : integer := 200000;

    type memory_t is array (0 to 65535) of std_logic_vector(7 downto 0);

    signal clk : std_logic := '0';
    signal reset : std_logic := '1';
    signal sim_done : boolean := false;

    signal mem_addr : std_logic_vector(15 downto 0);
    signal mem_data_in : std_logic_vector(7 downto 0);
    signal mem_data_out : std_logic_vector(7 downto 0);
    signal mem_read : std_logic;
    signal mem_write : std_logic;
    signal unsupported_opcode : std_logic;
    signal debug_pc : std_logic_vector(15 downto 0);
    signal debug_state : std_logic_vector(4 downto 0);

    signal io_tima_read : std_logic_vector(7 downto 0);
    signal io_tma_read : std_logic_vector(7 downto 0);
    signal io_tac_read : std_logic_vector(7 downto 0);
    signal timer_write_tima : std_logic;
    signal timer_write_tma : std_logic;
    signal timer_write_tac : std_logic;
    signal timer_interrupt_set : std_logic;

    signal result_nop_seen : std_logic := '0';
    signal result_ld_bc_seen : std_logic := '0';
    signal result_nop_value : std_logic_vector(7 downto 0) := x"00";
    signal result_ld_bc_value : std_logic_vector(7 downto 0) := x"00";
    signal tima_read_count : integer range 0 to MAX_CYCLES := 0;
    signal tima_read_zero_count : integer range 0 to MAX_CYCLES := 0;
    signal tima_read_nonzero_count : integer range 0 to MAX_CYCLES := 0;
    signal tima_write_count : integer range 0 to MAX_CYCLES := 0;

    signal mem : memory_t := (
        -- Main program.
        16#0000# => x"F3", -- DI
        16#0001# => x"3E", -- LD A,00
        16#0002# => x"00",
        16#0003# => x"E0", -- LDH (TMA),A
        16#0004# => x"06",
        16#0005# => x"3E", -- LD A,05
        16#0006# => x"05",
        16#0007# => x"E0", -- LDH (TAC),A
        16#0008# => x"07",
        16#0009# => x"CD", -- CALL start_timer
        16#000A# => x"40",
        16#000B# => x"00",
        16#000C# => x"00", -- NOP measured payload
        16#000D# => x"CD", -- CALL stop_timer
        16#000E# => x"60",
        16#000F# => x"00",
        16#0010# => x"EA", -- LD (C000),A
        16#0011# => x"00",
        16#0012# => x"C0",
        16#0013# => x"CD", -- CALL start_timer
        16#0014# => x"40",
        16#0015# => x"00",
        16#0016# => x"01", -- LD BC,1234 measured payload
        16#0017# => x"34",
        16#0018# => x"12",
        16#0019# => x"CD", -- CALL stop_timer
        16#001A# => x"60",
        16#001B# => x"00",
        16#001C# => x"EA", -- LD (C001),A
        16#001D# => x"01",
        16#001E# => x"C0",
        16#001F# => x"18", -- JR -2
        16#0020# => x"FE",

        -- start_timer, adapted from Blargg's instr_timing common timer loop.
        16#0040# => x"F5", -- PUSH AF
        16#0041# => x"AF", -- XOR A
        16#0042# => x"E0", -- LDH (TIMA),A
        16#0043# => x"05",
        16#0044# => x"F0", -- LDH A,(TIMA)
        16#0045# => x"05",
        16#0046# => x"B7", -- OR A
        16#0047# => x"20", -- JR NZ,start_timer loop
        16#0048# => x"F8",
        16#0049# => x"F1", -- POP AF
        16#004A# => x"C9", -- RET

        -- stop_timer, adapted from Blargg's instr_timing common timer loop.
        16#0060# => x"D5", -- PUSH DE
        16#0061# => x"CD", -- CALL stop_timer_word
        16#0062# => x"70",
        16#0063# => x"00",
        16#0064# => x"7B", -- LD A,E
        16#0065# => x"D6", -- SUB 10
        16#0066# => x"0A",
        16#0067# => x"D1", -- POP DE
        16#0068# => x"C9", -- RET

        16#0070# => x"16", -- LD D,00
        16#0071# => x"00",
        16#0072# => x"F0", -- LDH A,(TIMA)
        16#0073# => x"05",
        16#0074# => x"D6", -- SUB 5
        16#0075# => x"05",
        16#0076# => x"87", -- ADD A,A
        16#0077# => x"CB", -- RL D
        16#0078# => x"12",
        16#0079# => x"87", -- ADD A,A
        16#007A# => x"CB", -- RL D
        16#007B# => x"12",
        16#007C# => x"5F", -- LD E,A
        16#007D# => x"AF", -- XOR A
        16#007E# => x"E0", -- LDH (TIMA),A
        16#007F# => x"05",
        16#0080# => x"F0", -- LDH A,(TIMA)
        16#0081# => x"05",
        16#0082# => x"1B", -- DEC DE
        16#0083# => x"B7", -- OR A
        16#0084# => x"20", -- JR NZ,stop_timer_word loop
        16#0085# => x"F7",
        16#0086# => x"C9", -- RET
        others => x"00"
    );

    function to_hex_nibble(value_in : std_logic_vector(3 downto 0)) return character is
        variable nibble_v : integer;
    begin
        nibble_v := to_integer(unsigned(value_in));
        if nibble_v < 10 then
            return character'val(character'pos('0') + nibble_v);
        else
            return character'val(character'pos('A') + nibble_v - 10);
        end if;
    end function to_hex_nibble;

    function slv8_to_hex(value_in : std_logic_vector(7 downto 0)) return string is
        variable result_v : string(1 to 2);
    begin
        result_v(1) := to_hex_nibble(value_in(7 downto 4));
        result_v(2) := to_hex_nibble(value_in(3 downto 0));
        return result_v;
    end function slv8_to_hex;

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

    timer_write_tima <= '1' when mem_write = '1' and mem_addr = IO_TIMA_ADDR else '0';
    timer_write_tma <= '1' when mem_write = '1' and mem_addr = IO_TMA_ADDR else '0';
    timer_write_tac <= '1' when mem_write = '1' and mem_addr = IO_TAC_ADDR else '0';

    u_timer: entity work.timer
        generic map (
            G_DIV_COUNTER_RESET => G_TIMER_DIV_RESET
        )
        port map (
            clk => clk,
            reset => reset,
            write_data => mem_data_out,
            write_div => '0',
            write_tima => timer_write_tima,
            write_tma => timer_write_tma,
            write_tac => timer_write_tac,
            div_read => open,
            tima_read => io_tima_read,
            tma_read => io_tma_read,
            tac_read => io_tac_read,
            timer_interrupt_set => timer_interrupt_set
        );

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

    p_memory_read: process(mem_addr, mem, io_tima_read, io_tma_read, io_tac_read)
    begin
        case mem_addr is
            when IO_TIMA_ADDR =>
                mem_data_in <= io_tima_read;
            when IO_TMA_ADDR =>
                mem_data_in <= io_tma_read;
            when IO_TAC_ADDR =>
                mem_data_in <= io_tac_read;
            when others =>
                mem_data_in <= mem(to_integer(unsigned(mem_addr)));
        end case;
    end process p_memory_read;

    p_memory_write: process(clk)
    begin
        if rising_edge(clk) then
            if mem_write = '1' then
                if mem_addr = RESULT_NOP_ADDR then
                    result_nop_seen <= '1';
                    result_nop_value <= mem_data_out;
                    mem(to_integer(unsigned(mem_addr))) <= mem_data_out;
                elsif mem_addr = RESULT_LD_BC_ADDR then
                    result_ld_bc_seen <= '1';
                    result_ld_bc_value <= mem_data_out;
                    mem(to_integer(unsigned(mem_addr))) <= mem_data_out;
                elsif mem_addr /= IO_TIMA_ADDR and mem_addr /= IO_TMA_ADDR and
                      mem_addr /= IO_TAC_ADDR then
                    mem(to_integer(unsigned(mem_addr))) <= mem_data_out;
                end if;
            end if;
        end if;
    end process p_memory_write;

    p_bus_trace: process(clk)
    begin
        if rising_edge(clk) then
            if mem_write = '1' and mem_addr = IO_TIMA_ADDR then
                if tima_write_count < 8 then
                    report "TIMA write $" & slv8_to_hex(mem_data_out) severity note;
                end if;
                tima_write_count <= tima_write_count + 1;
            elsif mem_read = '1' and mem_addr = IO_TIMA_ADDR then
                if tima_read_count < 8 then
                    report "TIMA read $" & slv8_to_hex(mem_data_in) severity note;
                end if;
                tima_read_count <= tima_read_count + 1;
                if mem_data_in = x"00" then
                    tima_read_zero_count <= tima_read_zero_count + 1;
                else
                    tima_read_nonzero_count <= tima_read_nonzero_count + 1;
                end if;
            end if;
        end if;
    end process p_bus_trace;

    p_stimulus: process
    begin
        report "=== tb_cpu_timer_blargg_probe: Starting simulation ===" severity note;

        reset <= '1';
        wait for CLK_PERIOD * 4;
        reset <= '0';

        for i in 0 to MAX_CYCLES loop
            wait until rising_edge(clk);

            assert unsupported_opcode = '0'
                report "FAIL: unsupported opcode in timer Blargg probe"
                severity failure;

            if result_nop_seen = '1' and result_ld_bc_seen = '1' then
                assert result_nop_value = x"01"
                    report "FAIL: Blargg-style NOP timing should measure 1 cycle, got $" &
                           slv8_to_hex(result_nop_value)
                    severity failure;
                if result_ld_bc_value /= x"03" then
                    report "DIAGNOSTIC: Blargg-style LD BC,nn timing should measure 3 cycles, got $" &
                           slv8_to_hex(result_ld_bc_value)
                    severity warning;
                end if;
                report "Measured Blargg-style NOP result: $" &
                       slv8_to_hex(result_nop_value) severity note;
                report "Measured Blargg-style LD BC,nn result: $" &
                       slv8_to_hex(result_ld_bc_value) severity note;
                report "TIMA writes=" & integer'image(tima_write_count) &
                       " reads=" & integer'image(tima_read_count) &
                       " zero_reads=" & integer'image(tima_read_zero_count) &
                       " nonzero_reads=" & integer'image(tima_read_nonzero_count)
                       severity note;
                report "=== tb_cpu_timer_blargg_probe: DIAGNOSTIC COMPLETED ===" severity note;
                sim_done <= true;
                wait;
            end if;
        end loop;

        assert false
            report "FAIL: timer Blargg probe timeout near PC=$" &
                   slv8_to_hex(debug_pc(15 downto 8)) &
                   slv8_to_hex(debug_pc(7 downto 0)) &
                   ", state=" & slv8_to_hex("000" & debug_state) &
                   ", writes=" & integer'image(tima_write_count) &
                   ", reads=" & integer'image(tima_read_count) &
                   ", zero_reads=" & integer'image(tima_read_zero_count) &
                   ", nonzero_reads=" & integer'image(tima_read_nonzero_count)
            severity failure;
        wait;
    end process p_stimulus;

end architecture sim;
