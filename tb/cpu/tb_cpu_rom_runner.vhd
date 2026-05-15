-- =============================================================================
-- Module:      tb_cpu_rom_runner
-- Description: ROM-style CPU runner with Blargg-like serial transcript capture
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-14
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- This testbench is the first bridge toward external CPU test ROM execution.
-- It loads a real Game Boy ROM image and captures output through:
--   0xFF01 = SB data
--   0xFF02 = SC control, bit 7 starts a transfer
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_cpu_rom_runner is
    generic (
        G_ROM_PATH       : string := "../../gb-test-roms-master/cpu_instrs/individual/06-ld r,r.gb";
        G_TIMEOUT_CYCLES : integer := 10000000;
        G_VERBOSE_SERIAL : boolean := true
    );
end entity tb_cpu_rom_runner;

architecture sim of tb_cpu_rom_runner is

    constant CLK_PERIOD       : time := 238 ns; -- Approximately 4.194 MHz
    constant IO_SB_ADDR       : std_logic_vector(15 downto 0) := x"FF01";
    constant IO_SC_ADDR       : std_logic_vector(15 downto 0) := x"FF02";
    constant IO_DIV_ADDR      : std_logic_vector(15 downto 0) := x"FF04";
    constant IO_TIMA_ADDR     : std_logic_vector(15 downto 0) := x"FF05";
    constant IO_TMA_ADDR      : std_logic_vector(15 downto 0) := x"FF06";
    constant IO_TAC_ADDR      : std_logic_vector(15 downto 0) := x"FF07";
    constant IO_IF_ADDR       : std_logic_vector(15 downto 0) := x"FF0F";
    constant IO_LCDC_ADDR     : std_logic_vector(15 downto 0) := x"FF40";
    constant IO_STAT_ADDR     : std_logic_vector(15 downto 0) := x"FF41";
    constant IO_SCY_ADDR      : std_logic_vector(15 downto 0) := x"FF42";
    constant IO_SCX_ADDR      : std_logic_vector(15 downto 0) := x"FF43";
    constant IO_LY_ADDR       : std_logic_vector(15 downto 0) := x"FF44";
    constant IO_LYC_ADDR      : std_logic_vector(15 downto 0) := x"FF45";
    constant IO_BGP_ADDR      : std_logic_vector(15 downto 0) := x"FF47";
    constant IO_OBP0_ADDR     : std_logic_vector(15 downto 0) := x"FF48";
    constant IO_OBP1_ADDR     : std_logic_vector(15 downto 0) := x"FF49";
    constant IO_WY_ADDR       : std_logic_vector(15 downto 0) := x"FF4A";
    constant IO_WX_ADDR       : std_logic_vector(15 downto 0) := x"FF4B";
    constant IE_ADDR          : std_logic_vector(15 downto 0) := x"FFFF";
    constant MAX_SERIAL_LEN   : integer := 4096;

    type memory_t is array (0 to 65535) of std_logic_vector(7 downto 0);
    type serial_buffer_t is array (0 to MAX_SERIAL_LEN - 1) of std_logic_vector(7 downto 0);
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

    function slv16_to_hex(value_in : std_logic_vector(15 downto 0)) return string is
        variable result_v : string(1 to 4);
    begin
        result_v(1) := to_hex_nibble(value_in(15 downto 12));
        result_v(2) := to_hex_nibble(value_in(11 downto 8));
        result_v(3) := to_hex_nibble(value_in(7 downto 4));
        result_v(4) := to_hex_nibble(value_in(3 downto 0));
        return result_v;
    end function slv16_to_hex;

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
    signal boot_header_reached : std_logic := '0';
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

    signal serial_sb_reg : std_logic_vector(7 downto 0) := x"00";
    signal serial_sc_reg : std_logic_vector(7 downto 0) := x"7E";
    signal serial_count : integer range 0 to MAX_SERIAL_LEN := 0;
    signal serial_buffer : serial_buffer_t := (others => x"00");
    signal io_div_read : std_logic_vector(7 downto 0);
    signal io_tima_read : std_logic_vector(7 downto 0);
    signal io_tma_read : std_logic_vector(7 downto 0);
    signal io_tac_read : std_logic_vector(7 downto 0);
    signal io_if_reg : std_logic_vector(7 downto 0) := x"E0";
    signal io_lcdc_reg : std_logic_vector(7 downto 0) := x"91";
    signal io_stat_reg : std_logic_vector(7 downto 0) := x"80";
    signal io_scy_reg : std_logic_vector(7 downto 0) := x"00";
    signal io_scx_reg : std_logic_vector(7 downto 0) := x"00";
    signal io_ly_reg : std_logic_vector(7 downto 0) := x"00";
    signal io_lyc_reg : std_logic_vector(7 downto 0) := x"00";
    signal io_bgp_reg : std_logic_vector(7 downto 0) := x"FC";
    signal io_obp0_reg : std_logic_vector(7 downto 0) := x"FF";
    signal io_obp1_reg : std_logic_vector(7 downto 0) := x"FF";
    signal io_wy_reg : std_logic_vector(7 downto 0) := x"00";
    signal io_wx_reg : std_logic_vector(7 downto 0) := x"00";
    signal ie_reg : std_logic_vector(7 downto 0) := x"00";
    signal timer_interrupt_set : std_logic;
    signal timer_write_div : std_logic;
    signal timer_write_tima : std_logic;
    signal timer_write_tma : std_logic;
    signal timer_write_tac : std_logic;
    signal mem : memory_t := load_rom(G_ROM_PATH);

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

    interrupt_enable <= ie_reg(4 downto 0);
    interrupt_flags <= io_if_reg(4 downto 0);

    timer_write_div <= '1' when mem_write = '1' and mem_addr = IO_DIV_ADDR else '0';
    timer_write_tima <= '1' when mem_write = '1' and mem_addr = IO_TIMA_ADDR else '0';
    timer_write_tma <= '1' when mem_write = '1' and mem_addr = IO_TMA_ADDR else '0';
    timer_write_tac <= '1' when mem_write = '1' and mem_addr = IO_TAC_ADDR else '0';

    u_timer: entity work.timer
        port map (
            clk => clk,
            reset => reset,
            write_data => mem_data_out,
            write_div => timer_write_div,
            write_tima => timer_write_tima,
            write_tma => timer_write_tma,
            write_tac => timer_write_tac,
            div_read => io_div_read,
            tima_read => io_tima_read,
            tma_read => io_tma_read,
            tac_read => io_tac_read,
            timer_interrupt_set => timer_interrupt_set
        );

    p_memory_read: process(mem_addr, mem, serial_sb_reg, serial_sc_reg,
                           boot_header_reached,
                           io_div_read, io_tima_read, io_tma_read, io_tac_read,
                           io_if_reg, io_lcdc_reg, io_stat_reg, io_scy_reg,
                           io_ly_reg,
                           io_scx_reg, io_lyc_reg, io_bgp_reg, io_obp0_reg,
                           io_obp1_reg, io_wy_reg, io_wx_reg, ie_reg)
    begin
        case mem_addr is
            when IO_SB_ADDR =>
                mem_data_in <= serial_sb_reg;
            when IO_SC_ADDR =>
                mem_data_in <= serial_sc_reg;
            when IO_DIV_ADDR =>
                mem_data_in <= io_div_read;
            when IO_TIMA_ADDR =>
                mem_data_in <= io_tima_read;
            when IO_TMA_ADDR =>
                mem_data_in <= io_tma_read;
            when IO_TAC_ADDR =>
                mem_data_in <= io_tac_read;
            when IO_IF_ADDR =>
                mem_data_in <= io_if_reg;
            when IO_LCDC_ADDR =>
                mem_data_in <= io_lcdc_reg;
            when IO_STAT_ADDR =>
                mem_data_in <= io_stat_reg;
            when IO_SCY_ADDR =>
                mem_data_in <= io_scy_reg;
            when IO_SCX_ADDR =>
                mem_data_in <= io_scx_reg;
            when IO_LY_ADDR =>
                mem_data_in <= io_ly_reg;
            when IO_LYC_ADDR =>
                mem_data_in <= io_lyc_reg;
            when IO_BGP_ADDR =>
                mem_data_in <= io_bgp_reg;
            when IO_OBP0_ADDR =>
                mem_data_in <= io_obp0_reg;
            when IO_OBP1_ADDR =>
                mem_data_in <= io_obp1_reg;
            when IO_WY_ADDR =>
                mem_data_in <= io_wy_reg;
            when IO_WX_ADDR =>
                mem_data_in <= io_wx_reg;
            when IE_ADDR =>
                mem_data_in <= ie_reg;
            when others =>
                if boot_header_reached = '0' and unsigned(mem_addr) < x"0100" then
                    mem_data_in <= x"00";
                else
                    mem_data_in <= mem(to_integer(unsigned(mem_addr)));
                end if;
        end case;
    end process p_memory_read;

    p_memory_and_serial: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                serial_sb_reg <= x"00";
                serial_sc_reg <= x"7E";
                serial_count <= 0;
                boot_header_reached <= '0';
                io_if_reg <= x"E0";
                io_lcdc_reg <= x"91";
                io_stat_reg <= x"80";
                io_scy_reg <= x"00";
                io_scx_reg <= x"00";
                io_ly_reg <= x"00";
                io_lyc_reg <= x"00";
                io_bgp_reg <= x"FC";
                io_obp0_reg <= x"FF";
                io_obp1_reg <= x"FF";
                io_wy_reg <= x"00";
                io_wx_reg <= x"00";
                ie_reg <= x"00";
            else
                if io_ly_reg = x"99" then
                    io_ly_reg <= x"00";
                else
                    io_ly_reg <= std_logic_vector(unsigned(io_ly_reg) + 1);
                end if;

                if mem_read = '1' and mem_addr = x"0100" then
                    boot_header_reached <= '1';
                end if;

                if timer_interrupt_set = '1' then
                    io_if_reg(2) <= '1';
                end if;

                if interrupt_ack = '1' then
                    case interrupt_vector is
                        when "000" =>
                            io_if_reg(0) <= '0';
                        when "001" =>
                            io_if_reg(1) <= '0';
                        when "010" =>
                            io_if_reg(2) <= '0';
                        when "011" =>
                            io_if_reg(3) <= '0';
                        when others =>
                            io_if_reg(4) <= '0';
                    end case;
                end if;

                if mem_write = '1' then
                    if mem_addr = IO_SB_ADDR then
                        serial_sb_reg <= mem_data_out;
                    elsif mem_addr = IO_SC_ADDR then
                        serial_sc_reg <= mem_data_out;
                        if mem_data_out(7) = '1' then
                            assert serial_count < MAX_SERIAL_LEN
                                report "FAIL: ROM runner serial buffer overflow"
                                severity failure;
                            if serial_count < MAX_SERIAL_LEN then
                                serial_buffer(serial_count) <= serial_sb_reg;
                                serial_count <= serial_count + 1;
                            end if;
                            if G_VERBOSE_SERIAL then
                                report "SERIAL $" & slv8_to_hex(serial_sb_reg) severity note;
                            end if;
                        end if;
                    elsif mem_addr = IO_DIV_ADDR then
                        null;
                    elsif mem_addr = IO_TIMA_ADDR then
                        null;
                    elsif mem_addr = IO_TMA_ADDR then
                        null;
                    elsif mem_addr = IO_TAC_ADDR then
                        null;
                    elsif mem_addr = IO_IF_ADDR then
                        io_if_reg <= "111" & mem_data_out(4 downto 0);
                    elsif mem_addr = IO_LCDC_ADDR then
                        io_lcdc_reg <= mem_data_out;
                    elsif mem_addr = IO_STAT_ADDR then
                        io_stat_reg <= "1" & mem_data_out(6 downto 3) & "000";
                    elsif mem_addr = IO_SCY_ADDR then
                        io_scy_reg <= mem_data_out;
                    elsif mem_addr = IO_SCX_ADDR then
                        io_scx_reg <= mem_data_out;
                    elsif mem_addr = IO_LYC_ADDR then
                        io_lyc_reg <= mem_data_out;
                    elsif mem_addr = IO_BGP_ADDR then
                        io_bgp_reg <= mem_data_out;
                    elsif mem_addr = IO_OBP0_ADDR then
                        io_obp0_reg <= mem_data_out;
                    elsif mem_addr = IO_OBP1_ADDR then
                        io_obp1_reg <= mem_data_out;
                    elsif mem_addr = IO_WY_ADDR then
                        io_wy_reg <= mem_data_out;
                    elsif mem_addr = IO_WX_ADDR then
                        io_wx_reg <= mem_data_out;
                    elsif mem_addr = IE_ADDR then
                        ie_reg <= mem_data_out;
                    elsif unsigned(mem_addr) >= x"8000" and unsigned(mem_addr) <= x"FDFF" then
                        mem(to_integer(unsigned(mem_addr))) <= mem_data_out;
                    elsif unsigned(mem_addr) >= x"FF80" and unsigned(mem_addr) <= x"FFFE" then
                        mem(to_integer(unsigned(mem_addr))) <= mem_data_out;
                    end if;
                end if;
            end if;
        end if;
    end process p_memory_and_serial;

    p_stimulus: process
    begin
        report "=== tb_cpu_rom_runner: Starting simulation ===" severity note;

        reset <= '1';
        wait for CLK_PERIOD * 4;
        reset <= '0';

        report "ROM path: " & G_ROM_PATH severity note;

        for i in 0 to G_TIMEOUT_CYCLES loop
            wait until rising_edge(clk);
            if unsupported_opcode = '1' then
                assert false
                    report "FAIL: unsupported opcode near PC=$" & slv16_to_hex(debug_pc) &
                           ", prev=$" & slv8_to_hex(mem(to_integer(unsigned(debug_pc) - 1))) &
                           ", at=$" & slv8_to_hex(mem(to_integer(unsigned(debug_pc)))) &
                           ", next=$" & slv8_to_hex(mem(to_integer(unsigned(debug_pc) + 1)))
                    severity failure;
            end if;
            if serial_count >= 6 and
               serial_buffer(serial_count - 6) = x"50" and
               serial_buffer(serial_count - 5) = x"61" and
               serial_buffer(serial_count - 4) = x"73" and
               serial_buffer(serial_count - 3) = x"73" and
               serial_buffer(serial_count - 2) = x"65" and
               serial_buffer(serial_count - 1) = x"64" then
                report "=== tb_cpu_rom_runner: SERIAL TRANSCRIPT CONTAINS PASSED ===" severity note;
                report "=== tb_cpu_rom_runner: ALL TESTS PASSED ===" severity note;
                sim_done <= true;
                wait;
            end if;
            if serial_count >= 6 and
               serial_buffer(serial_count - 6) = x"46" and
               serial_buffer(serial_count - 5) = x"61" and
               serial_buffer(serial_count - 4) = x"69" and
               serial_buffer(serial_count - 3) = x"6C" and
               serial_buffer(serial_count - 2) = x"65" and
               serial_buffer(serial_count - 1) = x"64" then
                assert false
                    report "FAIL: Blargg serial transcript contains Failed"
                    severity failure;
            end if;
        end loop;

        assert halted = '0'
            report "FAIL: CPU halted unexpectedly during ROM runner"
            severity failure;

        assert false
            report "FAIL: ROM runner timeout, serial bytes=" & integer'image(serial_count) &
                   ", PC=$" & slv16_to_hex(debug_pc) &
                   ", instr=$" & slv8_to_hex(mem(16#DEF8#)) &
                   ", instr+1=$" & slv8_to_hex(mem(16#DEF9#)) &
                   ", instr+2=$" & slv8_to_hex(mem(16#DEFA#))
            severity failure;
        wait;
    end process p_stimulus;

end architecture sim;
