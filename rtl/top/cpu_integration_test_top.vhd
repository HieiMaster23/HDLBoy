-- =============================================================================
-- Module:      cpu_integration_test_top
-- Description: Hardware-visible CPU integration test with simple memory and I/O
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-11
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-11 - Initial CPU + memory + LED/seven-segment integration harness
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpu_integration_test_top is
    port (
        clk_50mhz : in  std_logic;
        reset_n   : in  std_logic;
        key_n     : in  std_logic_vector(3 downto 0);
        led       : out std_logic_vector(3 downto 0);
        seg       : out std_logic_vector(7 downto 0);
        digit_n   : out std_logic_vector(3 downto 0)
    );
end entity cpu_integration_test_top;

architecture rtl of cpu_integration_test_top is

    constant IO_LED_ADDR    : std_logic_vector(15 downto 0) := x"FF80";
    constant IO_STATUS_ADDR : std_logic_vector(15 downto 0) := x"FF81";
    constant PASS_CODE      : std_logic_vector(7 downto 0)  := x"A5";

    signal clk_vga_unused : std_logic;
    signal clk_cpu        : std_logic;
    signal pll_locked     : std_logic;
    signal pll_areset     : std_logic;
    signal display_reset  : std_logic;
    signal key_reset_n    : std_logic;
    signal system_reset_n : std_logic;
    signal reset_meta     : std_logic;
    signal reset_sync     : std_logic;
    signal reset          : std_logic;

    signal mem_addr      : std_logic_vector(15 downto 0);
    signal mem_data_in   : std_logic_vector(7 downto 0);
    signal mem_data_out  : std_logic_vector(7 downto 0);
    signal mem_read      : std_logic;
    signal mem_write     : std_logic;

    signal mem_c000 : std_logic_vector(7 downto 0);
    signal mem_ff80 : std_logic_vector(7 downto 0);
    signal mem_ff81 : std_logic_vector(7 downto 0);
    signal mem_fffc : std_logic_vector(7 downto 0);
    signal mem_fffd : std_logic_vector(7 downto 0);

    signal led_pattern       : std_logic_vector(3 downto 0);
    signal checkpoint_index  : unsigned(2 downto 0);
    signal checker_failed    : std_logic;
    signal final_passed      : std_logic;
    signal display_digits    : std_logic_vector(15 downto 0);
    signal debug_counter     : unsigned(7 downto 0);

    signal interrupt_ack      : std_logic;
    signal interrupt_vector   : std_logic_vector(2 downto 0);
    signal halted             : std_logic;
    signal ime_out            : std_logic;
    signal interrupt_pending  : std_logic;
    signal unsupported_opcode : std_logic;
    signal debug_a            : std_logic_vector(7 downto 0);
    signal debug_f            : std_logic_vector(7 downto 0);
    signal debug_b            : std_logic_vector(7 downto 0);
    signal debug_c            : std_logic_vector(7 downto 0);
    signal debug_d            : std_logic_vector(7 downto 0);
    signal debug_e            : std_logic_vector(7 downto 0);
    signal debug_h            : std_logic_vector(7 downto 0);
    signal debug_l            : std_logic_vector(7 downto 0);
    signal debug_pc           : std_logic_vector(15 downto 0);
    signal debug_sp           : std_logic_vector(15 downto 0);
    signal debug_state        : std_logic_vector(4 downto 0);

    signal stp_debug_a        : std_logic_vector(7 downto 0);
    signal stp_debug_f        : std_logic_vector(7 downto 0);
    signal stp_debug_b        : std_logic_vector(7 downto 0);
    signal stp_debug_c        : std_logic_vector(7 downto 0);
    signal stp_debug_d        : std_logic_vector(7 downto 0);
    signal stp_debug_e        : std_logic_vector(7 downto 0);
    signal stp_debug_h        : std_logic_vector(7 downto 0);
    signal stp_debug_l        : std_logic_vector(7 downto 0);
    signal stp_debug_pc       : std_logic_vector(15 downto 0);
    signal stp_debug_sp       : std_logic_vector(15 downto 0);
    signal stp_debug_state    : std_logic_vector(4 downto 0);
    signal stp_mem_addr       : std_logic_vector(15 downto 0);
    signal stp_mem_data_in    : std_logic_vector(7 downto 0);
    signal stp_mem_data_out   : std_logic_vector(7 downto 0);
    signal stp_mem_read       : std_logic;
    signal stp_mem_write      : std_logic;
    signal stp_led_pattern    : std_logic_vector(3 downto 0);
    signal stp_checkpoint     : std_logic_vector(2 downto 0);
    signal stp_final_passed   : std_logic;
    signal stp_checker_failed : std_logic;
    signal stp_unsupported    : std_logic;

    signal stp_m3_flow        : std_logic_vector(31 downto 0);
    signal stp_m3_bus         : std_logic_vector(31 downto 0);
    signal stp_m3_regs_ab     : std_logic_vector(31 downto 0);
    signal stp_m3_regs_dehl   : std_logic_vector(31 downto 0);
    signal stp_m3_sp_flags    : std_logic_vector(31 downto 0);
    signal stp_m3_reset_keys  : std_logic_vector(31 downto 0);
    signal stp_heartbeat_0    : std_logic;
    signal stp_heartbeat_1    : std_logic;
    signal stp_heartbeat_2    : std_logic;
    signal stp_heartbeat_3    : std_logic;
    signal stp_heartbeat_4    : std_logic;
    signal stp_heartbeat_5    : std_logic;
    signal stp_heartbeat_6    : std_logic;
    signal stp_heartbeat_7    : std_logic;
    signal stp_key0_raw       : std_logic;
    signal stp_key1_raw       : std_logic;
    signal stp_key2_raw       : std_logic;
    signal stp_key3_raw       : std_logic;
    signal stp_reset_button_n : std_logic;
    signal stp_key_reset_n    : std_logic;
    signal stp_system_reset_n : std_logic;
    signal stp_pll_locked     : std_logic;
    signal stp_reset_internal : std_logic;

    attribute keep     : boolean;
    attribute preserve : boolean;
    attribute noprune  : boolean;

    attribute keep of stp_debug_a        : signal is true;
    attribute keep of stp_debug_f        : signal is true;
    attribute keep of stp_debug_b        : signal is true;
    attribute keep of stp_debug_c        : signal is true;
    attribute keep of stp_debug_d        : signal is true;
    attribute keep of stp_debug_e        : signal is true;
    attribute keep of stp_debug_h        : signal is true;
    attribute keep of stp_debug_l        : signal is true;
    attribute keep of stp_debug_pc       : signal is true;
    attribute keep of stp_debug_sp       : signal is true;
    attribute keep of stp_debug_state    : signal is true;
    attribute keep of stp_mem_addr       : signal is true;
    attribute keep of stp_mem_data_in    : signal is true;
    attribute keep of stp_mem_data_out   : signal is true;
    attribute keep of stp_mem_read       : signal is true;
    attribute keep of stp_mem_write      : signal is true;
    attribute keep of stp_led_pattern    : signal is true;
    attribute keep of stp_checkpoint     : signal is true;
    attribute keep of stp_final_passed   : signal is true;
    attribute keep of stp_checker_failed : signal is true;
    attribute keep of stp_unsupported    : signal is true;
    attribute keep of stp_m3_flow        : signal is true;
    attribute keep of stp_m3_bus         : signal is true;
    attribute keep of stp_m3_regs_ab     : signal is true;
    attribute keep of stp_m3_regs_dehl   : signal is true;
    attribute keep of stp_m3_sp_flags    : signal is true;
    attribute keep of stp_m3_reset_keys  : signal is true;
    attribute keep of stp_heartbeat_0    : signal is true;
    attribute keep of stp_heartbeat_1    : signal is true;
    attribute keep of stp_heartbeat_2    : signal is true;
    attribute keep of stp_heartbeat_3    : signal is true;
    attribute keep of stp_heartbeat_4    : signal is true;
    attribute keep of stp_heartbeat_5    : signal is true;
    attribute keep of stp_heartbeat_6    : signal is true;
    attribute keep of stp_heartbeat_7    : signal is true;
    attribute keep of stp_key0_raw       : signal is true;
    attribute keep of stp_key1_raw       : signal is true;
    attribute keep of stp_key2_raw       : signal is true;
    attribute keep of stp_key3_raw       : signal is true;
    attribute keep of stp_reset_button_n : signal is true;
    attribute keep of stp_key_reset_n    : signal is true;
    attribute keep of stp_system_reset_n : signal is true;
    attribute keep of stp_pll_locked     : signal is true;
    attribute keep of stp_reset_internal : signal is true;

    attribute preserve of stp_debug_a        : signal is true;
    attribute preserve of stp_debug_f        : signal is true;
    attribute preserve of stp_debug_b        : signal is true;
    attribute preserve of stp_debug_c        : signal is true;
    attribute preserve of stp_debug_d        : signal is true;
    attribute preserve of stp_debug_e        : signal is true;
    attribute preserve of stp_debug_h        : signal is true;
    attribute preserve of stp_debug_l        : signal is true;
    attribute preserve of stp_debug_pc       : signal is true;
    attribute preserve of stp_debug_sp       : signal is true;
    attribute preserve of stp_debug_state    : signal is true;
    attribute preserve of stp_mem_addr       : signal is true;
    attribute preserve of stp_mem_data_in    : signal is true;
    attribute preserve of stp_mem_data_out   : signal is true;
    attribute preserve of stp_mem_read       : signal is true;
    attribute preserve of stp_mem_write      : signal is true;
    attribute preserve of stp_led_pattern    : signal is true;
    attribute preserve of stp_checkpoint     : signal is true;
    attribute preserve of stp_final_passed   : signal is true;
    attribute preserve of stp_checker_failed : signal is true;
    attribute preserve of stp_unsupported    : signal is true;
    attribute preserve of stp_m3_flow        : signal is true;
    attribute preserve of stp_m3_bus         : signal is true;
    attribute preserve of stp_m3_regs_ab     : signal is true;
    attribute preserve of stp_m3_regs_dehl   : signal is true;
    attribute preserve of stp_m3_sp_flags    : signal is true;
    attribute preserve of stp_m3_reset_keys  : signal is true;
    attribute preserve of stp_heartbeat_0    : signal is true;
    attribute preserve of stp_heartbeat_1    : signal is true;
    attribute preserve of stp_heartbeat_2    : signal is true;
    attribute preserve of stp_heartbeat_3    : signal is true;
    attribute preserve of stp_heartbeat_4    : signal is true;
    attribute preserve of stp_heartbeat_5    : signal is true;
    attribute preserve of stp_heartbeat_6    : signal is true;
    attribute preserve of stp_heartbeat_7    : signal is true;
    attribute preserve of stp_key0_raw       : signal is true;
    attribute preserve of stp_key1_raw       : signal is true;
    attribute preserve of stp_key2_raw       : signal is true;
    attribute preserve of stp_key3_raw       : signal is true;
    attribute preserve of stp_reset_button_n : signal is true;
    attribute preserve of stp_key_reset_n    : signal is true;
    attribute preserve of stp_system_reset_n : signal is true;
    attribute preserve of stp_pll_locked     : signal is true;
    attribute preserve of stp_reset_internal : signal is true;

    attribute noprune of stp_debug_a        : signal is true;
    attribute noprune of stp_debug_f        : signal is true;
    attribute noprune of stp_debug_b        : signal is true;
    attribute noprune of stp_debug_c        : signal is true;
    attribute noprune of stp_debug_d        : signal is true;
    attribute noprune of stp_debug_e        : signal is true;
    attribute noprune of stp_debug_h        : signal is true;
    attribute noprune of stp_debug_l        : signal is true;
    attribute noprune of stp_debug_pc       : signal is true;
    attribute noprune of stp_debug_sp       : signal is true;
    attribute noprune of stp_debug_state    : signal is true;
    attribute noprune of stp_mem_addr       : signal is true;
    attribute noprune of stp_mem_data_in    : signal is true;
    attribute noprune of stp_mem_data_out   : signal is true;
    attribute noprune of stp_mem_read       : signal is true;
    attribute noprune of stp_mem_write      : signal is true;
    attribute noprune of stp_led_pattern    : signal is true;
    attribute noprune of stp_checkpoint     : signal is true;
    attribute noprune of stp_final_passed   : signal is true;
    attribute noprune of stp_checker_failed : signal is true;
    attribute noprune of stp_unsupported    : signal is true;
    attribute noprune of stp_m3_flow        : signal is true;
    attribute noprune of stp_m3_bus         : signal is true;
    attribute noprune of stp_m3_regs_ab     : signal is true;
    attribute noprune of stp_m3_regs_dehl   : signal is true;
    attribute noprune of stp_m3_sp_flags    : signal is true;
    attribute noprune of stp_m3_reset_keys  : signal is true;
    attribute noprune of stp_heartbeat_0    : signal is true;
    attribute noprune of stp_heartbeat_1    : signal is true;
    attribute noprune of stp_heartbeat_2    : signal is true;
    attribute noprune of stp_heartbeat_3    : signal is true;
    attribute noprune of stp_heartbeat_4    : signal is true;
    attribute noprune of stp_heartbeat_5    : signal is true;
    attribute noprune of stp_heartbeat_6    : signal is true;
    attribute noprune of stp_heartbeat_7    : signal is true;
    attribute noprune of stp_key0_raw       : signal is true;
    attribute noprune of stp_key1_raw       : signal is true;
    attribute noprune of stp_key2_raw       : signal is true;
    attribute noprune of stp_key3_raw       : signal is true;
    attribute noprune of stp_reset_button_n : signal is true;
    attribute noprune of stp_key_reset_n    : signal is true;
    attribute noprune of stp_system_reset_n : signal is true;
    attribute noprune of stp_pll_locked     : signal is true;
    attribute noprune of stp_reset_internal : signal is true;

    function rom_byte(addr_in : std_logic_vector(15 downto 0)) return std_logic_vector is
        variable data_v : std_logic_vector(7 downto 0);
    begin
        case addr_in is
            when x"0000" => data_v := x"31"; -- LD SP,$FFFE
            when x"0001" => data_v := x"FE";
            when x"0002" => data_v := x"FF";
            when x"0003" => data_v := x"21"; -- LD HL,$FF80
            when x"0004" => data_v := x"80";
            when x"0005" => data_v := x"FF";
            when x"0006" => data_v := x"3E"; -- LD A,$01
            when x"0007" => data_v := x"01";
            when x"0008" => data_v := x"77"; -- LD (HL),A
            when x"0009" => data_v := x"06"; -- LD B,$03
            when x"000A" => data_v := x"03";
            when x"000B" => data_v := x"80"; -- ADD A,B -> $04
            when x"000C" => data_v := x"77"; -- LD (HL),A
            when x"000D" => data_v := x"21"; -- LD HL,$C000
            when x"000E" => data_v := x"00";
            when x"000F" => data_v := x"C0";
            when x"0010" => data_v := x"3E"; -- LD A,$12
            when x"0011" => data_v := x"12";
            when x"0012" => data_v := x"77"; -- LD (HL),A
            when x"0013" => data_v := x"3E"; -- LD A,$00
            when x"0014" => data_v := x"00";
            when x"0015" => data_v := x"7E"; -- LD A,(HL)
            when x"0016" => data_v := x"21"; -- LD HL,$FF80
            when x"0017" => data_v := x"80";
            when x"0018" => data_v := x"FF";
            when x"0019" => data_v := x"3E"; -- LD A,$08
            when x"001A" => data_v := x"08";
            when x"001B" => data_v := x"77"; -- LD (HL),A
            when x"001C" => data_v := x"06"; -- LD B,$03
            when x"001D" => data_v := x"03";
            when x"001E" => data_v := x"80"; -- ADD A,B -> $0B
            when x"001F" => data_v := x"05"; -- DEC B -> $02
            when x"0020" => data_v := x"90"; -- SUB B -> $09
            when x"0021" => data_v := x"77"; -- LD (HL),A
            when x"0022" => data_v := x"C5"; -- PUSH BC
            when x"0023" => data_v := x"D1"; -- POP DE
            when x"0024" => data_v := x"CD"; -- CALL $0040
            when x"0025" => data_v := x"40";
            when x"0026" => data_v := x"00";
            when x"0027" => data_v := x"21"; -- LD HL,$FF80
            when x"0028" => data_v := x"80";
            when x"0029" => data_v := x"FF";
            when x"002A" => data_v := x"77"; -- LD (HL),A, final pattern $0D
            when x"002B" => data_v := x"21"; -- LD HL,$FF81
            when x"002C" => data_v := x"81";
            when x"002D" => data_v := x"FF";
            when x"002E" => data_v := x"3E"; -- LD A,$A5
            when x"002F" => data_v := x"A5";
            when x"0030" => data_v := x"77"; -- LD (HL),A, pass code
            when x"0031" => data_v := x"18"; -- JR -2
            when x"0032" => data_v := x"FE";

            when x"0040" => data_v := x"3C"; -- INC A -> $0A
            when x"0041" => data_v := x"4F"; -- LD C,A
            when x"0042" => data_v := x"3E"; -- LD A,$F0
            when x"0043" => data_v := x"F0";
            when x"0044" => data_v := x"A1"; -- AND C -> $00
            when x"0045" => data_v := x"3E"; -- LD A,$05
            when x"0046" => data_v := x"05";
            when x"0047" => data_v := x"B1"; -- OR C -> $0F
            when x"0048" => data_v := x"A8"; -- XOR B -> $0D
            when x"0049" => data_v := x"BF"; -- CP A
            when x"004A" => data_v := x"C9"; -- RET
            when others  => data_v := x"00";
        end case;

        return data_v;
    end function rom_byte;

    function expected_checkpoint(index_in : unsigned(2 downto 0)) return std_logic_vector is
        variable value_v : std_logic_vector(3 downto 0);
    begin
        case index_in is
            when "000" => value_v := x"1";
            when "001" => value_v := x"4";
            when "010" => value_v := x"8";
            when "011" => value_v := x"9";
            when "100" => value_v := x"D";
            when others => value_v := x"0";
        end case;

        return value_v;
    end function expected_checkpoint;

begin

    pll_areset <= not reset_n;
    key_reset_n <= key_n(0) and key_n(1) and key_n(2) and key_n(3);
    system_reset_n <= reset_n and key_reset_n;
    display_reset <= not system_reset_n;

    u_pll: entity work.pll_core
        port map (
            areset => pll_areset,
            inclk0 => clk_50mhz,
            c0     => clk_vga_unused,
            c1     => clk_cpu,
            locked => pll_locked
        );

    p_reset_sync: process(clk_cpu)
    begin
        if rising_edge(clk_cpu) then
            reset_meta <= (not system_reset_n) or (not pll_locked);
            reset_sync <= reset_meta;
        end if;
    end process p_reset_sync;

    reset <= reset_sync;

    u_cpu: entity work.cpu
        port map (
            clk                => clk_cpu,
            reset              => reset,
            mem_addr           => mem_addr,
            mem_data_in        => mem_data_in,
            mem_data_out       => mem_data_out,
            mem_read           => mem_read,
            mem_write          => mem_write,
            interrupt_enable   => "00000",
            interrupt_flags    => "00000",
            interrupt_ack      => interrupt_ack,
            interrupt_vector   => interrupt_vector,
            halted             => halted,
            ime_out            => ime_out,
            interrupt_pending  => interrupt_pending,
            unsupported_opcode => unsupported_opcode,
            debug_a            => debug_a,
            debug_f            => debug_f,
            debug_b            => debug_b,
            debug_c            => debug_c,
            debug_d            => debug_d,
            debug_e            => debug_e,
            debug_h            => debug_h,
            debug_l            => debug_l,
            debug_pc           => debug_pc,
            debug_sp           => debug_sp,
            debug_state        => debug_state
        );

    p_memory_read: process(mem_addr, mem_c000, mem_ff80, mem_ff81, mem_fffc, mem_fffd)
    begin
        case mem_addr is
            when x"C000" =>
                mem_data_in <= mem_c000;
            when x"FF80" =>
                mem_data_in <= mem_ff80;
            when x"FF81" =>
                mem_data_in <= mem_ff81;
            when x"FFFC" =>
                mem_data_in <= mem_fffc;
            when x"FFFD" =>
                mem_data_in <= mem_fffd;
            when others =>
                mem_data_in <= rom_byte(mem_addr);
        end case;
    end process p_memory_read;

    p_memory_write: process(clk_cpu)
    begin
        if rising_edge(clk_cpu) then
            if reset = '1' then
                mem_c000 <= (others => '0');
                mem_ff80 <= (others => '0');
                mem_ff81 <= (others => '0');
                mem_fffc <= (others => '0');
                mem_fffd <= (others => '0');
            elsif mem_write = '1' then
                case mem_addr is
                    when x"C000" =>
                        mem_c000 <= mem_data_out;
                    when x"FF80" =>
                        mem_ff80 <= mem_data_out;
                    when x"FF81" =>
                        mem_ff81 <= mem_data_out;
                    when x"FFFC" =>
                        mem_fffc <= mem_data_out;
                    when x"FFFD" =>
                        mem_fffd <= mem_data_out;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process p_memory_write;

    p_checker: process(clk_cpu)
    begin
        if rising_edge(clk_cpu) then
            debug_counter <= debug_counter + 1;

            if reset = '1' then
                led_pattern <= x"0";
                checkpoint_index <= (others => '0');
                checker_failed <= '0';
                final_passed <= '0';
            else
                if unsupported_opcode = '1' then
                    checker_failed <= '1';
                end if;

                if mem_write = '1' and mem_addr = IO_LED_ADDR then
                    led_pattern <= mem_data_out(3 downto 0);
                    if checkpoint_index < to_unsigned(5, 3) then
                        if mem_data_out(3 downto 0) /= expected_checkpoint(checkpoint_index) then
                            checker_failed <= '1';
                        end if;
                        checkpoint_index <= checkpoint_index + 1;
                    else
                        checker_failed <= '1';
                    end if;
                end if;

                if mem_write = '1' and mem_addr = IO_STATUS_ADDR then
                    if mem_data_out = PASS_CODE and checker_failed = '0' and
                       checkpoint_index = to_unsigned(5, 3) and
                       mem_c000 = x"12" and
                       debug_b = x"02" and debug_c = x"0A" and
                       debug_d = x"02" and debug_e = x"00" and
                       debug_sp = x"FFFE" then
                        final_passed <= '1';
                    else
                        checker_failed <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process p_checker;

    p_signaltap_probes: process(clk_cpu)
    begin
        if rising_edge(clk_cpu) then
            stp_debug_a <= debug_a;
            stp_debug_f <= debug_f;
            stp_debug_b <= debug_b;
            stp_debug_c <= debug_c;
            stp_debug_d <= debug_d;
            stp_debug_e <= debug_e;
            stp_debug_h <= debug_h;
            stp_debug_l <= debug_l;
            stp_debug_pc <= debug_pc;
            stp_debug_sp <= debug_sp;
            stp_debug_state <= debug_state;
            stp_mem_addr <= mem_addr;
            stp_mem_data_in <= mem_data_in;
            stp_mem_data_out <= mem_data_out;
            stp_mem_read <= mem_read;
            stp_mem_write <= mem_write;
            stp_led_pattern <= led_pattern;
            stp_checkpoint <= std_logic_vector(checkpoint_index);
            stp_final_passed <= final_passed;
            stp_checker_failed <= checker_failed;
            stp_unsupported <= unsupported_opcode;

            -- Packed SignalTap probes keep the M3 capture readable in Quartus.
            -- stp_m3_flow[31:16] = PC, [15:11] = CPU state,
            -- [10:8] = checkpoint, [7] = final_passed, [6] = checker_failed,
            -- [5] = unsupported opcode, [4] = mem_write, [3] = mem_read,
            -- [2] = internal reset, [1] = system_reset_n, [0] = key_reset_n.
            stp_m3_flow <= debug_pc & debug_state &
                            std_logic_vector(checkpoint_index) &
                            final_passed & checker_failed &
                            unsupported_opcode & mem_write & mem_read &
                            reset & system_reset_n & key_reset_n;

            -- stp_m3_bus[31:16] = memory address,
            -- [15:8] = memory write data, [7:0] = memory read data.
            stp_m3_bus <= mem_addr & mem_data_out & mem_data_in;

            -- stp_m3_regs_ab[31:24] = A, [23:16] = F, [15:8] = B, [7:0] = C.
            stp_m3_regs_ab <= debug_a & debug_f & debug_b & debug_c;

            -- stp_m3_regs_dehl[31:24] = D, [23:16] = E, [15:8] = H, [7:0] = L.
            stp_m3_regs_dehl <= debug_d & debug_e & debug_h & debug_l;

            -- stp_m3_sp_flags[31:16] = SP, [15:12] = visible LED pattern,
            -- remaining bits are reserved for later M3 debug expansion.
            stp_m3_sp_flags <= debug_sp & led_pattern & x"000";

            -- stp_m3_reset_keys[31:24] = free-running debug counter,
            -- [23:20] = raw key_n pins, [19] = reset_n, [18] = key_reset_n,
            -- [17] = system_reset_n, [16] = pll_locked, [15] = internal reset,
            -- [14:0] = reserved.
            stp_m3_reset_keys <= std_logic_vector(debug_counter) & key_n &
                                  reset_n & key_reset_n & system_reset_n &
                                  pll_locked & reset & "000000000000000";

            -- Beginner-friendly scalar probes for Quartus 13 Node Finder.
            stp_heartbeat_0 <= debug_counter(0);
            stp_heartbeat_1 <= debug_counter(1);
            stp_heartbeat_2 <= debug_counter(2);
            stp_heartbeat_3 <= debug_counter(3);
            stp_heartbeat_4 <= debug_counter(4);
            stp_heartbeat_5 <= debug_counter(5);
            stp_heartbeat_6 <= debug_counter(6);
            stp_heartbeat_7 <= debug_counter(7);
            stp_key0_raw <= key_n(0);
            stp_key1_raw <= key_n(1);
            stp_key2_raw <= key_n(2);
            stp_key3_raw <= key_n(3);
            stp_reset_button_n <= reset_n;
            stp_key_reset_n <= key_reset_n;
            stp_system_reset_n <= system_reset_n;
            stp_pll_locked <= pll_locked;
            stp_reset_internal <= reset;
        end if;
    end process p_signaltap_probes;

    display_digits <= x"1234" when final_passed = '1' else
                      x"EEEE" when checker_failed = '1' else
                      x"0000";

    u_display: entity work.seven_segment_mux
        port map (
            clk     => clk_50mhz,
            reset   => display_reset,
            enable  => '1',
            digits  => display_digits,
            seg     => seg,
            digit_n => digit_n
        );

    led <= not led_pattern when checker_failed = '0' else "0000";

end architecture rtl;
