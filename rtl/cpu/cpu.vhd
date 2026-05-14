-- =============================================================================
-- Module:      cpu
-- Description: Incremental Sharp LR35902 CPU core for M3 bring-up
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-11
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-11 - Initial multi-cycle CPU subset with memory bus and stack support
-- 2026-05-13 - Expanded LD r,(HL) and LD (HL),r execution paths
-- 2026-05-13 - Added ALU A,(HL) execution using the existing HL read state
-- 2026-05-13 - Added read-modify-write execution for INC (HL) and DEC (HL)
-- 2026-05-13 - Added LDH and absolute A memory transfer execution
-- 2026-05-14 - Added first Blargg shell bring-up opcodes
-- 2026-05-14 - Added memory ready input for registered memory wait states
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gb_types_pkg.all;

entity cpu is
    port (
        clk                : in  std_logic;
        reset              : in  std_logic;

        mem_addr           : out std_logic_vector(15 downto 0);
        mem_data_in        : in  std_logic_vector(7 downto 0);
        mem_data_out       : out std_logic_vector(7 downto 0);
        mem_read           : out std_logic;
        mem_write          : out std_logic;
        mem_ready          : in  std_logic;

        interrupt_enable   : in  std_logic_vector(4 downto 0);
        interrupt_flags    : in  std_logic_vector(4 downto 0);
        interrupt_ack      : out std_logic;
        interrupt_vector   : out std_logic_vector(2 downto 0);

        halted             : out std_logic;
        ime_out            : out std_logic;
        interrupt_pending  : out std_logic;
        unsupported_opcode : out std_logic;

        debug_a            : out std_logic_vector(7 downto 0);
        debug_f            : out std_logic_vector(7 downto 0);
        debug_b            : out std_logic_vector(7 downto 0);
        debug_c            : out std_logic_vector(7 downto 0);
        debug_d            : out std_logic_vector(7 downto 0);
        debug_e            : out std_logic_vector(7 downto 0);
        debug_h            : out std_logic_vector(7 downto 0);
        debug_l            : out std_logic_vector(7 downto 0);
        debug_pc           : out std_logic_vector(15 downto 0);
        debug_sp           : out std_logic_vector(15 downto 0);
        debug_state        : out std_logic_vector(4 downto 0)
    );
end entity cpu;

architecture rtl of cpu is

    type cpu_state_t is (
        S_FETCH,
        S_DECODE,
        S_READ_IMM_LO,
        S_READ_IMM_HI,
        S_MEM_READ_HL,
        S_MEM_WRITE_HL,
        S_MEM_RMW_WRITE_HL,
        S_MEM_READ_REG_ADDR,
        S_MEM_WRITE_REG_ADDR,
        S_MEM_READ_ADDR,
        S_MEM_WRITE_ADDR,
        S_MEM_WRITE_SP_LO,
        S_MEM_WRITE_SP_HI,
        S_CB_READ_HL,
        S_CB_WRITE_HL,
        S_INT_PUSH_HI,
        S_INT_PUSH_LO,
        S_PUSH_HI,
        S_PUSH_LO,
        S_POP_LO,
        S_POP_HI,
        S_CALL_PUSH_HI,
        S_CALL_PUSH_LO,
        S_RET_READ_LO,
        S_RET_READ_HI,
        S_HALT
    );

    signal state_reg : cpu_state_t;
    signal state_next : cpu_state_t;

    signal opcode_reg : std_logic_vector(7 downto 0);
    signal imm_lo_reg : std_logic_vector(7 downto 0);
    signal addr_tmp_reg : std_logic_vector(15 downto 0);
    signal stack_lo_reg : std_logic_vector(7 downto 0);
    signal mem_rmw_data_reg : std_logic_vector(7 downto 0);
    signal cb_result_reg : std_logic_vector(7 downto 0);
    signal unsupported_reg : std_logic;
    signal ime_reg : std_logic;
    signal ei_pending_reg : std_logic;
    signal halted_reg : std_logic;
    signal interrupt_vector_reg : std_logic_vector(2 downto 0);

    signal dec_valid : std_logic;
    signal dec_class : std_logic_vector(3 downto 0);
    signal dec_dst : std_logic_vector(2 downto 0);
    signal dec_src : std_logic_vector(2 downto 0);
    signal dec_pair : std_logic_vector(1 downto 0);
    signal dec_alu_op : std_logic_vector(3 downto 0);
    signal dec_imm_bytes : std_logic_vector(1 downto 0);
    signal dec_reads_memory : std_logic;
    signal dec_writes_memory : std_logic;
    signal dec_writes_register : std_logic;
    signal dec_writes_flags : std_logic;

    signal reg_read_sel_a : std_logic_vector(2 downto 0);
    signal reg_read_sel_b : std_logic_vector(2 downto 0);
    signal reg_read_data_a : std_logic_vector(7 downto 0);
    signal reg_read_data_b : std_logic_vector(7 downto 0);
    signal reg_write_enable : std_logic;
    signal reg_write_sel : std_logic_vector(2 downto 0);
    signal reg_write_data : std_logic_vector(7 downto 0);
    signal pair_write_enable : std_logic;
    signal pair_write_sel : std_logic_vector(1 downto 0);
    signal pair_write_data : std_logic_vector(15 downto 0);
    signal flags_write_enable : std_logic;
    signal flags_in_sig : std_logic_vector(3 downto 0);
    signal pc_write_enable : std_logic;
    signal pc_in_sig : std_logic_vector(15 downto 0);
    signal pc_out_sig : std_logic_vector(15 downto 0);
    signal sp_write_enable : std_logic;
    signal sp_in_sig : std_logic_vector(15 downto 0);
    signal sp_out_sig : std_logic_vector(15 downto 0);
    signal a_sig : std_logic_vector(7 downto 0);
    signal f_sig : std_logic_vector(7 downto 0);
    signal b_sig : std_logic_vector(7 downto 0);
    signal c_sig : std_logic_vector(7 downto 0);
    signal d_sig : std_logic_vector(7 downto 0);
    signal e_sig : std_logic_vector(7 downto 0);
    signal h_sig : std_logic_vector(7 downto 0);
    signal l_sig : std_logic_vector(7 downto 0);
    signal hl_sig : std_logic_vector(15 downto 0);
    signal flags_sig : std_logic_vector(3 downto 0);

    signal alu_a_sig : std_logic_vector(7 downto 0);
    signal alu_b_sig : std_logic_vector(7 downto 0);
    signal alu_result_sig : std_logic_vector(7 downto 0);
    signal alu_flags_sig : std_logic_vector(3 downto 0);
    signal alu_op_sig : std_logic_vector(3 downto 0);

    signal instr_complete : std_logic;
    signal pending_interrupt_sig : std_logic;

    function priority_vector(pending_in : std_logic_vector(4 downto 0)) return std_logic_vector is
    begin
        if pending_in(0) = '1' then
            return "000";
        elsif pending_in(1) = '1' then
            return "001";
        elsif pending_in(2) = '1' then
            return "010";
        elsif pending_in(3) = '1' then
            return "011";
        else
            return "100";
        end if;
    end function priority_vector;

    function interrupt_address(vector_in : std_logic_vector(2 downto 0)) return std_logic_vector is
    begin
        case vector_in is
            when "000" =>
                return x"0040";
            when "001" =>
                return x"0048";
            when "010" =>
                return x"0050";
            when "011" =>
                return x"0058";
            when others =>
                return x"0060";
        end case;
    end function interrupt_address;

    function inc16(value_in : std_logic_vector(15 downto 0)) return std_logic_vector is
    begin
        return std_logic_vector(unsigned(value_in) + 1);
    end function inc16;

    function dec16(value_in : std_logic_vector(15 downto 0)) return std_logic_vector is
    begin
        return std_logic_vector(unsigned(value_in) - 1);
    end function dec16;

    function add_signed8(base_in : std_logic_vector(15 downto 0);
                         offset_in : std_logic_vector(7 downto 0)) return std_logic_vector is
        variable base_s : signed(16 downto 0);
        variable off_s  : signed(16 downto 0);
        variable sum_s  : signed(16 downto 0);
    begin
        base_s := signed('0' & base_in);
        off_s := resize(signed(offset_in), 17);
        sum_s := base_s + off_s;
        return std_logic_vector(sum_s(15 downto 0));
    end function add_signed8;

    function condition_met(opcode_in : std_logic_vector(7 downto 0);
                           flags_in : std_logic_vector(3 downto 0)) return std_logic is
    begin
        case opcode_in(4 downto 3) is
            when "00" =>
                return not flags_in(CPU_FLAG_Z_BIT); -- NZ
            when "01" =>
                return flags_in(CPU_FLAG_Z_BIT);     -- Z
            when "10" =>
                return not flags_in(CPU_FLAG_C_BIT); -- NC
            when others =>
                return flags_in(CPU_FLAG_C_BIT);     -- C
        end case;
    end function condition_met;

    function register_pair_addr(opcode_in : std_logic_vector(7 downto 0);
                                b_in : std_logic_vector(7 downto 0);
                                c_in : std_logic_vector(7 downto 0);
                                d_in : std_logic_vector(7 downto 0);
                                e_in : std_logic_vector(7 downto 0);
                                h_in : std_logic_vector(7 downto 0);
                                l_in : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        if opcode_in = x"E2" or opcode_in = x"F2" then
            return x"FF" & c_in;
        elsif opcode_in = x"02" or opcode_in = x"0A" then
            return b_in & c_in;
        elsif opcode_in = x"12" or opcode_in = x"1A" then
            return d_in & e_in;
        else
            return h_in & l_in;
        end if;
    end function register_pair_addr;

    function register_pair_word(pair_in : std_logic_vector(1 downto 0);
                                b_in : std_logic_vector(7 downto 0);
                                c_in : std_logic_vector(7 downto 0);
                                d_in : std_logic_vector(7 downto 0);
                                e_in : std_logic_vector(7 downto 0);
                                h_in : std_logic_vector(7 downto 0);
                                l_in : std_logic_vector(7 downto 0);
                                sp_in : std_logic_vector(15 downto 0)) return std_logic_vector is
    begin
        case pair_in is
            when CPU_PAIR_BC =>
                return b_in & c_in;
            when CPU_PAIR_DE =>
                return d_in & e_in;
            when CPU_PAIR_HL =>
                return h_in & l_in;
            when others =>
                return sp_in;
        end case;
    end function register_pair_word;

    function rst_vector(opcode_in : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        return x"00" & "00" & opcode_in(5 downto 3) & "000";
    end function rst_vector;

    function is_rst_opcode(opcode_in : std_logic_vector(7 downto 0)) return std_logic is
    begin
        if opcode_in = x"C7" or opcode_in = x"CF" or opcode_in = x"D7" or
           opcode_in = x"DF" or opcode_in = x"E7" or opcode_in = x"EF" or
           opcode_in = x"F7" or opcode_in = x"FF" then
            return '1';
        else
            return '0';
        end if;
    end function is_rst_opcode;

    function cb_exec_result(opcode_in : std_logic_vector(7 downto 0);
                            value_in : std_logic_vector(7 downto 0);
                            carry_in : std_logic) return std_logic_vector is
        variable result_v : std_logic_vector(7 downto 0);
        variable bit_v    : integer range 0 to 7;
    begin
        result_v := value_in;
        bit_v := to_integer(unsigned(opcode_in(5 downto 3)));

        if opcode_in(7 downto 6) = "00" then
            case opcode_in(5 downto 3) is
                when "000" =>
                    result_v := value_in(6 downto 0) & value_in(7);
                when "001" =>
                    result_v := value_in(0) & value_in(7 downto 1);
                when "010" =>
                    result_v := value_in(6 downto 0) & carry_in;
                when "011" =>
                    result_v := carry_in & value_in(7 downto 1);
                when "100" =>
                    result_v := value_in(6 downto 0) & '0';
                when "101" =>
                    result_v := value_in(7) & value_in(7 downto 1);
                when "110" =>
                    result_v := value_in(3 downto 0) & value_in(7 downto 4);
                when others =>
                    result_v := '0' & value_in(7 downto 1);
            end case;
        elsif opcode_in(7 downto 6) = "10" then
            result_v(bit_v) := '0';
        elsif opcode_in(7 downto 6) = "11" then
            result_v(bit_v) := '1';
        else
            result_v := value_in;
        end if;

        return result_v;
    end function cb_exec_result;

    function cb_exec_flags(opcode_in : std_logic_vector(7 downto 0);
                           value_in : std_logic_vector(7 downto 0);
                           result_in : std_logic_vector(7 downto 0);
                           flags_in : std_logic_vector(3 downto 0)) return std_logic_vector is
        variable flags_v : std_logic_vector(3 downto 0);
        variable bit_v   : integer range 0 to 7;
    begin
        flags_v := flags_in;
        bit_v := to_integer(unsigned(opcode_in(5 downto 3)));

        if opcode_in(7 downto 6) = "00" then
            if result_in = x"00" then
                flags_v(CPU_FLAG_Z_BIT) := '1';
            else
                flags_v(CPU_FLAG_Z_BIT) := '0';
            end if;
            flags_v(CPU_FLAG_N_BIT) := '0';
            flags_v(CPU_FLAG_H_BIT) := '0';
            if opcode_in(5 downto 3) = "000" or opcode_in(5 downto 3) = "010" or
               opcode_in(5 downto 3) = "100" then
                flags_v(CPU_FLAG_C_BIT) := value_in(7);
            elsif opcode_in(5 downto 3) = "110" then
                flags_v(CPU_FLAG_C_BIT) := '0';
            else
                flags_v(CPU_FLAG_C_BIT) := value_in(0);
            end if;
        elsif opcode_in(7 downto 6) = "01" then
            if value_in(bit_v) = '0' then
                flags_v(CPU_FLAG_Z_BIT) := '1';
            else
                flags_v(CPU_FLAG_Z_BIT) := '0';
            end if;
            flags_v(CPU_FLAG_N_BIT) := '0';
            flags_v(CPU_FLAG_H_BIT) := '1';
        end if;

        return flags_v;
    end function cb_exec_flags;

    function stack_pair_value(opcode_in : std_logic_vector(7 downto 0);
                              a_in : std_logic_vector(7 downto 0);
                              f_in : std_logic_vector(7 downto 0);
                              b_in : std_logic_vector(7 downto 0);
                              c_in : std_logic_vector(7 downto 0);
                              d_in : std_logic_vector(7 downto 0);
                              e_in : std_logic_vector(7 downto 0);
                              h_in : std_logic_vector(7 downto 0);
                              l_in : std_logic_vector(7 downto 0)) return std_logic_vector is
        variable pair_v : std_logic_vector(15 downto 0);
    begin
        case opcode_in(5 downto 4) is
            when CPU_PAIR_BC =>
                pair_v := b_in & c_in;
            when CPU_PAIR_DE =>
                pair_v := d_in & e_in;
            when CPU_PAIR_HL =>
                pair_v := h_in & l_in;
            when others =>
                pair_v := a_in & (f_in(7 downto 4) & "0000");
        end case;
        return pair_v;
    end function stack_pair_value;

    function state_to_slv(state_in : cpu_state_t) return std_logic_vector is
    begin
        case state_in is
            when S_FETCH        => return "00000";
            when S_DECODE       => return "00001";
            when S_READ_IMM_LO  => return "00010";
            when S_READ_IMM_HI  => return "00011";
            when S_MEM_READ_HL  => return "00100";
            when S_MEM_WRITE_HL => return "00101";
            when S_MEM_RMW_WRITE_HL => return "00110";
            when S_MEM_READ_REG_ADDR => return "00111";
            when S_MEM_WRITE_REG_ADDR => return "01000";
            when S_MEM_READ_ADDR => return "01001";
            when S_MEM_WRITE_ADDR => return "01010";
            when S_MEM_WRITE_SP_LO => return "01011";
            when S_MEM_WRITE_SP_HI => return "01100";
            when S_CB_READ_HL   => return "01101";
            when S_CB_WRITE_HL  => return "01110";
            when S_INT_PUSH_HI  => return "01111";
            when S_INT_PUSH_LO  => return "10000";
            when S_PUSH_HI      => return "10001";
            when S_PUSH_LO      => return "10010";
            when S_POP_LO       => return "10011";
            when S_POP_HI       => return "10100";
            when S_CALL_PUSH_HI => return "10101";
            when S_CALL_PUSH_LO => return "10110";
            when S_RET_READ_LO  => return "10111";
            when S_RET_READ_HI  => return "11000";
            when others         => return "11001";
        end case;
    end function state_to_slv;

begin

    u_decoder: entity work.decoder
        port map (
            opcode          => opcode_reg,
            valid           => dec_valid,
            instr_class     => dec_class,
            dst_sel         => dec_dst,
            src_sel         => dec_src,
            pair_sel        => dec_pair,
            alu_op          => dec_alu_op,
            immediate_bytes => dec_imm_bytes,
            reads_memory    => dec_reads_memory,
            writes_memory   => dec_writes_memory,
            writes_register => dec_writes_register,
            writes_flags    => dec_writes_flags
        );

    u_registers: entity work.registers
        port map (
            clk                => clk,
            reset              => reset,
            read_sel_a         => reg_read_sel_a,
            read_sel_b         => reg_read_sel_b,
            read_data_a        => reg_read_data_a,
            read_data_b        => reg_read_data_b,
            write_enable       => reg_write_enable,
            write_sel          => reg_write_sel,
            write_data         => reg_write_data,
            pair_write_enable  => pair_write_enable,
            pair_write_sel     => pair_write_sel,
            pair_write_data    => pair_write_data,
            flags_write_enable => flags_write_enable,
            flags_in           => flags_in_sig,
            pc_write_enable    => pc_write_enable,
            pc_in              => pc_in_sig,
            pc_out             => pc_out_sig,
            sp_write_enable    => sp_write_enable,
            sp_in              => sp_in_sig,
            sp_out             => sp_out_sig,
            a_out              => a_sig,
            f_out              => f_sig,
            b_out              => b_sig,
            c_out              => c_sig,
            d_out              => d_sig,
            e_out              => e_sig,
            h_out              => h_sig,
            l_out              => l_sig,
            hl_out             => hl_sig,
            flags_out          => flags_sig
        );

    u_alu: entity work.alu
        port map (
            op       => alu_op_sig,
            a_in     => alu_a_sig,
            b_in     => alu_b_sig,
            flags_in => flags_sig,
            result   => alu_result_sig,
            flags    => alu_flags_sig
        );

    pending_interrupt_sig <= '1' when (interrupt_enable and interrupt_flags) /= "00000" else '0';

    p_state: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state_reg <= S_FETCH;
                opcode_reg <= x"00";
                imm_lo_reg <= x"00";
                addr_tmp_reg <= (others => '0');
                stack_lo_reg <= x"00";
                mem_rmw_data_reg <= x"00";
                cb_result_reg <= x"00";
                unsupported_reg <= '0';
                ime_reg <= '0';
                ei_pending_reg <= '0';
                halted_reg <= '0';
                interrupt_vector_reg <= "000";
            else
                state_reg <= state_next;

                if instr_complete = '1' and ei_pending_reg = '1' then
                    ime_reg <= '1';
                    ei_pending_reg <= '0';
                end if;

                case state_reg is
                    when S_FETCH =>
                        if ime_reg = '1' and pending_interrupt_sig = '1' then
                            interrupt_vector_reg <= priority_vector(interrupt_enable and interrupt_flags);
                            ime_reg <= '0';
                            ei_pending_reg <= '0';
                            halted_reg <= '0';
                        else
                            if mem_ready = '1' then
                                opcode_reg <= mem_data_in;
                            end if;
                        end if;

                    when S_DECODE =>
                        if dec_valid = '0' then
                            unsupported_reg <= '1';
                        end if;
                        if opcode_reg = x"F3" then
                            ime_reg <= '0';
                            ei_pending_reg <= '0';
                        elsif opcode_reg = x"FB" then
                            ei_pending_reg <= '1';
                        elsif opcode_reg = x"76" then
                            halted_reg <= '1';
                        end if;

                    when S_READ_IMM_LO =>
                        if mem_ready = '1' then
                        imm_lo_reg <= mem_data_in;
                        if opcode_reg = x"E0" or opcode_reg = x"F0" then
                            addr_tmp_reg <= x"FF" & mem_data_in;
                        end if;
                        end if;

                    when S_READ_IMM_HI =>
                        if mem_ready = '1' and (opcode_reg = x"08" or
                           opcode_reg = x"C2" or opcode_reg = x"C3" or
                           opcode_reg = x"C4" or opcode_reg = x"CA" or
                           opcode_reg = x"CC" or opcode_reg = x"D2" or
                           opcode_reg = x"D4" or opcode_reg = x"DA" or
                           opcode_reg = x"DC" or opcode_reg = x"CD" or
                           opcode_reg = x"EA" or opcode_reg = x"FA") then
                            addr_tmp_reg <= mem_data_in & imm_lo_reg;
                        end if;

                    when S_POP_LO | S_RET_READ_LO =>
                        if mem_ready = '1' then
                        stack_lo_reg <= mem_data_in;
                        end if;

                    when S_RET_READ_HI =>
                        if opcode_reg = x"D9" then
                            ime_reg <= '1';
                        end if;

                    when S_MEM_READ_HL =>
                        if mem_ready = '1' then
                        if dec_class = DEC_CLASS_INC_R or dec_class = DEC_CLASS_DEC_R then
                            mem_rmw_data_reg <= alu_result_sig;
                        end if;
                        end if;

                    when S_CB_READ_HL =>
                        if mem_ready = '1' then
                            cb_result_reg <= cb_exec_result(imm_lo_reg, mem_data_in,
                                                            flags_sig(CPU_FLAG_C_BIT));
                        end if;

                    when S_HALT =>
                        if pending_interrupt_sig = '1' then
                            halted_reg <= '0';
                        end if;

                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process p_state;

    p_control: process(state_reg, opcode_reg, imm_lo_reg, addr_tmp_reg, stack_lo_reg,
                       mem_data_in, mem_rmw_data_reg, cb_result_reg,
                       dec_valid, dec_class, dec_dst, dec_src, dec_pair, dec_alu_op,
                       dec_reads_memory, dec_writes_memory,
                       reg_read_data_b, pc_out_sig, sp_out_sig, a_sig, f_sig,
                       b_sig, c_sig, d_sig, e_sig, h_sig, l_sig, hl_sig,
                       flags_sig, alu_result_sig, alu_flags_sig,
                       pending_interrupt_sig, ime_reg, interrupt_vector_reg, mem_ready)
        variable opcode_pair_v : std_logic_vector(1 downto 0);
        variable jr_base_v     : std_logic_vector(15 downto 0);
        variable push_value_v  : std_logic_vector(15 downto 0);
        variable reg_addr_v    : std_logic_vector(15 downto 0);
        variable pair_word_v   : std_logic_vector(15 downto 0);
        variable cb_value_v    : std_logic_vector(7 downto 0);
        variable cb_result_v   : std_logic_vector(7 downto 0);
        variable cb_flags_v    : std_logic_vector(3 downto 0);
        variable add17_v       : unsigned(16 downto 0);
        variable add13_v       : unsigned(12 downto 0);
        variable sp_low_sum_v  : unsigned(8 downto 0);
        variable sp_nib_sum_v  : unsigned(4 downto 0);
    begin
        state_next <= S_FETCH;
        mem_addr <= (others => '0');
        mem_data_out <= (others => '0');
        mem_read <= '0';
        mem_write <= '0';
        interrupt_ack <= '0';
        interrupt_vector <= interrupt_vector_reg;

        reg_read_sel_a <= CPU_REG_A;
        reg_read_sel_b <= dec_src;
        reg_write_enable <= '0';
        reg_write_sel <= dec_dst;
        reg_write_data <= reg_read_data_b;
        pair_write_enable <= '0';
        pair_write_sel <= dec_pair;
        pair_write_data <= (others => '0');
        flags_write_enable <= '0';
        flags_in_sig <= flags_sig;
        pc_write_enable <= '0';
        pc_in_sig <= pc_out_sig;
        sp_write_enable <= '0';
        sp_in_sig <= sp_out_sig;

        alu_a_sig <= a_sig;
        alu_b_sig <= reg_read_data_b;
        alu_op_sig <= dec_alu_op;
        instr_complete <= '0';

        opcode_pair_v := opcode_reg(5 downto 4);
        jr_base_v := inc16(pc_out_sig);
        push_value_v := stack_pair_value(opcode_reg, a_sig, f_sig, b_sig, c_sig,
                                         d_sig, e_sig, h_sig, l_sig);
        reg_addr_v := register_pair_addr(opcode_reg, b_sig, c_sig, d_sig, e_sig,
                                         h_sig, l_sig);
        pair_word_v := register_pair_word(dec_pair, b_sig, c_sig, d_sig, e_sig,
                                          h_sig, l_sig, sp_out_sig);
        cb_value_v := x"00";
        cb_result_v := x"00";
        cb_flags_v := flags_sig;
        add17_v := (others => '0');
        add13_v := (others => '0');
        sp_low_sum_v := (others => '0');
        sp_nib_sum_v := (others => '0');

        case state_reg is
            when S_FETCH =>
                if ime_reg = '1' and pending_interrupt_sig = '1' then
                    state_next <= S_INT_PUSH_HI;
                else
                    mem_addr <= pc_out_sig;
                    mem_read <= '1';
                    if mem_ready = '1' then
                        pc_write_enable <= '1';
                        pc_in_sig <= inc16(pc_out_sig);
                        state_next <= S_DECODE;
                    else
                        state_next <= S_FETCH;
                    end if;
                end if;

            when S_DECODE =>
                state_next <= S_FETCH;
                instr_complete <= '1';

                if dec_valid = '0' then
                    state_next <= S_FETCH;

                elsif dec_class = DEC_CLASS_NOP then
                    state_next <= S_FETCH;

                elsif dec_class = DEC_CLASS_LD_R_N then
                    instr_complete <= '0';
                    state_next <= S_READ_IMM_LO;

                elsif dec_class = DEC_CLASS_LD_R_R then
                    if dec_reads_memory = '1' then
                        instr_complete <= '0';
                        state_next <= S_MEM_READ_HL;
                    elsif dec_writes_memory = '1' then
                        instr_complete <= '0';
                        state_next <= S_MEM_WRITE_HL;
                    elsif dec_src /= CPU_REG_HL_MEM and dec_dst /= CPU_REG_HL_MEM then
                        reg_write_enable <= '1';
                        reg_write_sel <= dec_dst;
                        reg_write_data <= reg_read_data_b;
                    else
                        state_next <= S_FETCH;
                    end if;

                elsif dec_class = DEC_CLASS_LD_16_N then
                    instr_complete <= '0';
                    state_next <= S_READ_IMM_LO;

                elsif dec_class = DEC_CLASS_INC_R or dec_class = DEC_CLASS_DEC_R then
                    if dec_reads_memory = '1' then
                        instr_complete <= '0';
                        state_next <= S_MEM_READ_HL;
                    else
                        reg_read_sel_b <= dec_src;
                        alu_a_sig <= reg_read_data_b;
                        alu_b_sig <= x"01";
                        alu_op_sig <= dec_alu_op;
                        reg_write_enable <= '1';
                        reg_write_sel <= dec_dst;
                        reg_write_data <= alu_result_sig;
                        flags_write_enable <= '1';
                        flags_in_sig <= alu_flags_sig;
                    end if;

                elsif dec_class = DEC_CLASS_ALU_R then
                    if dec_reads_memory = '1' then
                        instr_complete <= '0';
                        state_next <= S_MEM_READ_HL;
                    else
                        reg_read_sel_b <= dec_src;
                        alu_a_sig <= a_sig;
                        alu_b_sig <= reg_read_data_b;
                        alu_op_sig <= dec_alu_op;
                        if dec_alu_op /= ALU_OP_CP then
                            reg_write_enable <= '1';
                            reg_write_sel <= CPU_REG_A;
                            reg_write_data <= alu_result_sig;
                        end if;
                        flags_write_enable <= '1';
                        flags_in_sig <= alu_flags_sig;
                    end if;

                elsif dec_class = DEC_CLASS_ALU_N then
                    instr_complete <= '0';
                    state_next <= S_READ_IMM_LO;

                elsif dec_class = DEC_CLASS_MEM_HL then
                    add17_v := unsigned('0' & hl_sig) + unsigned('0' & pair_word_v);
                    add13_v := unsigned('0' & hl_sig(11 downto 0)) +
                               unsigned('0' & pair_word_v(11 downto 0));
                    pair_write_enable <= '1';
                    pair_write_sel <= CPU_PAIR_HL;
                    pair_write_data <= std_logic_vector(add17_v(15 downto 0));
                    flags_write_enable <= '1';
                    flags_in_sig(CPU_FLAG_Z_BIT) <= flags_sig(CPU_FLAG_Z_BIT);
                    flags_in_sig(CPU_FLAG_N_BIT) <= '0';
                    if add13_v(12) = '1' then
                        flags_in_sig(CPU_FLAG_H_BIT) <= '1';
                    else
                        flags_in_sig(CPU_FLAG_H_BIT) <= '0';
                    end if;
                    flags_in_sig(CPU_FLAG_C_BIT) <= add17_v(16);

                elsif dec_class = DEC_CLASS_INC_16 then
                    if dec_pair = CPU_PAIR_AF then
                        sp_write_enable <= '1';
                        sp_in_sig <= inc16(sp_out_sig);
                    else
                        pair_write_enable <= '1';
                        pair_write_sel <= dec_pair;
                        pair_write_data <= inc16(pair_word_v);
                    end if;

                elsif dec_class = DEC_CLASS_DEC_16 then
                    if dec_pair = CPU_PAIR_AF then
                        sp_write_enable <= '1';
                        sp_in_sig <= dec16(sp_out_sig);
                    else
                        pair_write_enable <= '1';
                        pair_write_sel <= dec_pair;
                        pair_write_data <= dec16(pair_word_v);
                    end if;

                elsif dec_class = DEC_CLASS_JUMP then
                    if opcode_reg = x"C2" or opcode_reg = x"C3" or
                       opcode_reg = x"C4" or opcode_reg = x"CA" or
                       opcode_reg = x"CC" or opcode_reg = x"D2" or
                       opcode_reg = x"D4" or opcode_reg = x"DA" or
                       opcode_reg = x"DC" or opcode_reg = x"CD" then
                        instr_complete <= '0';
                        state_next <= S_READ_IMM_LO;
                    elsif is_rst_opcode(opcode_reg) = '1' then
                        instr_complete <= '0';
                        state_next <= S_CALL_PUSH_HI;
                    elsif opcode_reg = x"18" or opcode_reg = x"20" or
                          opcode_reg = x"28" or opcode_reg = x"30" or
                          opcode_reg = x"38" then
                        instr_complete <= '0';
                        state_next <= S_READ_IMM_LO;
                    elsif opcode_reg = x"C9" or opcode_reg = x"D9" then
                        instr_complete <= '0';
                        state_next <= S_RET_READ_LO;
                    elsif opcode_reg = x"E9" then
                        pc_write_enable <= '1';
                        pc_in_sig <= hl_sig;
                    elsif opcode_reg = x"C0" or opcode_reg = x"C8" or
                          opcode_reg = x"D0" or opcode_reg = x"D8" then
                        if condition_met(opcode_reg, flags_sig) = '1' then
                            instr_complete <= '0';
                            state_next <= S_RET_READ_LO;
                        else
                            state_next <= S_FETCH;
                        end if;
                    else
                        state_next <= S_FETCH;
                    end if;

                elsif dec_class = DEC_CLASS_STACK then
                    instr_complete <= '0';
                    if opcode_reg(2) = '0' then
                        state_next <= S_POP_LO;
                    else
                        state_next <= S_PUSH_HI;
                    end if;

                elsif dec_class = DEC_CLASS_LD_MEM then
                    instr_complete <= '0';
                    if opcode_reg = x"02" or opcode_reg = x"12" or
                       opcode_reg = x"22" or opcode_reg = x"32" or
                       opcode_reg = x"E2" then
                        state_next <= S_MEM_WRITE_REG_ADDR;
                    elsif opcode_reg = x"0A" or opcode_reg = x"1A" or
                          opcode_reg = x"2A" or opcode_reg = x"3A" or
                          opcode_reg = x"F2" then
                        state_next <= S_MEM_READ_REG_ADDR;
                    else
                        state_next <= S_READ_IMM_LO;
                    end if;

                elsif dec_class = DEC_CLASS_CONTROL then
                    if opcode_reg = x"76" then
                        instr_complete <= '0';
                        state_next <= S_HALT;
                    elsif opcode_reg = x"CB" then
                        instr_complete <= '0';
                        state_next <= S_READ_IMM_LO;
                    elsif opcode_reg = x"F9" then
                        sp_write_enable <= '1';
                        sp_in_sig <= hl_sig;
                    elsif opcode_reg = x"27" then
                        alu_a_sig <= a_sig;
                        alu_b_sig <= x"00";
                        alu_op_sig <= ALU_OP_DAA;
                        reg_write_enable <= '1';
                        reg_write_sel <= CPU_REG_A;
                        reg_write_data <= alu_result_sig;
                        flags_write_enable <= '1';
                        flags_in_sig <= alu_flags_sig;
                    elsif opcode_reg = x"2F" then
                        reg_write_enable <= '1';
                        reg_write_sel <= CPU_REG_A;
                        reg_write_data <= not a_sig;
                        flags_write_enable <= '1';
                        flags_in_sig(CPU_FLAG_Z_BIT) <= flags_sig(CPU_FLAG_Z_BIT);
                        flags_in_sig(CPU_FLAG_N_BIT) <= '1';
                        flags_in_sig(CPU_FLAG_H_BIT) <= '1';
                        flags_in_sig(CPU_FLAG_C_BIT) <= flags_sig(CPU_FLAG_C_BIT);
                    elsif opcode_reg = x"37" then
                        flags_write_enable <= '1';
                        flags_in_sig(CPU_FLAG_Z_BIT) <= flags_sig(CPU_FLAG_Z_BIT);
                        flags_in_sig(CPU_FLAG_N_BIT) <= '0';
                        flags_in_sig(CPU_FLAG_H_BIT) <= '0';
                        flags_in_sig(CPU_FLAG_C_BIT) <= '1';
                    elsif opcode_reg = x"3F" then
                        flags_write_enable <= '1';
                        flags_in_sig(CPU_FLAG_Z_BIT) <= flags_sig(CPU_FLAG_Z_BIT);
                        flags_in_sig(CPU_FLAG_N_BIT) <= '0';
                        flags_in_sig(CPU_FLAG_H_BIT) <= '0';
                        flags_in_sig(CPU_FLAG_C_BIT) <= not flags_sig(CPU_FLAG_C_BIT);
                    elsif opcode_reg = x"07" or opcode_reg = x"0F" or
                          opcode_reg = x"17" or opcode_reg = x"1F" then
                        reg_write_enable <= '1';
                        reg_write_sel <= CPU_REG_A;
                        flags_write_enable <= '1';
                        flags_in_sig(CPU_FLAG_Z_BIT) <= '0';
                        flags_in_sig(CPU_FLAG_N_BIT) <= '0';
                        flags_in_sig(CPU_FLAG_H_BIT) <= '0';
                        if opcode_reg = x"07" then
                            reg_write_data <= a_sig(6 downto 0) & a_sig(7);
                            flags_in_sig(CPU_FLAG_C_BIT) <= a_sig(7);
                        elsif opcode_reg = x"0F" then
                            reg_write_data <= a_sig(0) & a_sig(7 downto 1);
                            flags_in_sig(CPU_FLAG_C_BIT) <= a_sig(0);
                        elsif opcode_reg = x"17" then
                            reg_write_data <= a_sig(6 downto 0) & flags_sig(CPU_FLAG_C_BIT);
                            flags_in_sig(CPU_FLAG_C_BIT) <= a_sig(7);
                        else
                            reg_write_data <= flags_sig(CPU_FLAG_C_BIT) & a_sig(7 downto 1);
                            flags_in_sig(CPU_FLAG_C_BIT) <= a_sig(0);
                        end if;
                    else
                        -- DI/EI bookkeeping is handled by the sequential process.
                        state_next <= S_FETCH;
                    end if;

                else
                    state_next <= S_FETCH;
                end if;

            when S_READ_IMM_LO =>
                mem_addr <= pc_out_sig;
                mem_read <= '1';

                if mem_ready = '0' then
                    state_next <= S_READ_IMM_LO;
                else
                if opcode_reg = x"CB" then
                    pc_write_enable <= '1';
                    pc_in_sig <= inc16(pc_out_sig);
                    if mem_data_in(2 downto 0) = CPU_REG_HL_MEM then
                        instr_complete <= '0';
                        state_next <= S_CB_READ_HL;
                    else
                        case mem_data_in(2 downto 0) is
                            when CPU_REG_A =>
                                cb_value_v := a_sig;
                            when CPU_REG_B =>
                                cb_value_v := b_sig;
                            when CPU_REG_C =>
                                cb_value_v := c_sig;
                            when CPU_REG_D =>
                                cb_value_v := d_sig;
                            when CPU_REG_E =>
                                cb_value_v := e_sig;
                            when CPU_REG_H =>
                                cb_value_v := h_sig;
                            when CPU_REG_L =>
                                cb_value_v := l_sig;
                            when others =>
                                cb_value_v := x"00";
                        end case;

                        cb_result_v := cb_exec_result(mem_data_in, cb_value_v,
                                                      flags_sig(CPU_FLAG_C_BIT));
                        cb_flags_v := cb_exec_flags(mem_data_in, cb_value_v,
                                                    cb_result_v, flags_sig);
                        if mem_data_in(7 downto 6) /= "01" then
                            reg_write_enable <= '1';
                            reg_write_sel <= mem_data_in(2 downto 0);
                            reg_write_data <= cb_result_v;
                        end if;
                        if mem_data_in(7 downto 6) /= "10" and mem_data_in(7 downto 6) /= "11" then
                            flags_write_enable <= '1';
                            flags_in_sig <= cb_flags_v;
                        end if;
                        instr_complete <= '1';
                        state_next <= S_FETCH;
                    end if;
                elsif opcode_reg = x"E8" or opcode_reg = x"F8" then
                    pc_write_enable <= '1';
                    pc_in_sig <= inc16(pc_out_sig);
                    sp_low_sum_v := unsigned('0' & sp_out_sig(7 downto 0)) +
                                    unsigned('0' & mem_data_in);
                    sp_nib_sum_v := unsigned('0' & sp_out_sig(3 downto 0)) +
                                    unsigned('0' & mem_data_in(3 downto 0));
                    flags_write_enable <= '1';
                    flags_in_sig(CPU_FLAG_Z_BIT) <= '0';
                    flags_in_sig(CPU_FLAG_N_BIT) <= '0';
                    if sp_nib_sum_v(4) = '1' then
                        flags_in_sig(CPU_FLAG_H_BIT) <= '1';
                    else
                        flags_in_sig(CPU_FLAG_H_BIT) <= '0';
                    end if;
                    flags_in_sig(CPU_FLAG_C_BIT) <= sp_low_sum_v(8);
                    if opcode_reg = x"E8" then
                        sp_write_enable <= '1';
                        sp_in_sig <= add_signed8(sp_out_sig, mem_data_in);
                    else
                        pair_write_enable <= '1';
                        pair_write_sel <= CPU_PAIR_HL;
                        pair_write_data <= add_signed8(sp_out_sig, mem_data_in);
                    end if;
                    instr_complete <= '1';
                    state_next <= S_FETCH;
                elsif opcode_reg = x"18" then
                    pc_write_enable <= '1';
                    jr_base_v := inc16(pc_out_sig);
                    pc_in_sig <= add_signed8(jr_base_v, mem_data_in);
                    instr_complete <= '1';
                    state_next <= S_FETCH;
                elsif opcode_reg = x"20" or opcode_reg = x"28" or
                      opcode_reg = x"30" or opcode_reg = x"38" then
                    pc_write_enable <= '1';
                    jr_base_v := inc16(pc_out_sig);
                    if condition_met(opcode_reg, flags_sig) = '1' then
                        pc_in_sig <= add_signed8(jr_base_v, mem_data_in);
                    else
                        pc_in_sig <= jr_base_v;
                    end if;
                    instr_complete <= '1';
                    state_next <= S_FETCH;
                elsif dec_class = DEC_CLASS_LD_R_N then
                    pc_write_enable <= '1';
                    pc_in_sig <= inc16(pc_out_sig);
                    if dec_writes_memory = '1' then
                        state_next <= S_MEM_WRITE_HL;
                    else
                        reg_write_enable <= '1';
                        reg_write_sel <= dec_dst;
                        reg_write_data <= mem_data_in;
                        instr_complete <= '1';
                        state_next <= S_FETCH;
                    end if;
                elsif dec_class = DEC_CLASS_ALU_N then
                    pc_write_enable <= '1';
                    pc_in_sig <= inc16(pc_out_sig);
                    alu_a_sig <= a_sig;
                    alu_b_sig <= mem_data_in;
                    alu_op_sig <= dec_alu_op;
                    if dec_alu_op /= ALU_OP_CP then
                        reg_write_enable <= '1';
                        reg_write_sel <= CPU_REG_A;
                        reg_write_data <= alu_result_sig;
                    end if;
                    flags_write_enable <= '1';
                    flags_in_sig <= alu_flags_sig;
                    instr_complete <= '1';
                    state_next <= S_FETCH;
                elsif opcode_reg = x"E0" then
                    pc_write_enable <= '1';
                    pc_in_sig <= inc16(pc_out_sig);
                    state_next <= S_MEM_WRITE_ADDR;
                elsif opcode_reg = x"F0" then
                    pc_write_enable <= '1';
                    pc_in_sig <= inc16(pc_out_sig);
                    state_next <= S_MEM_READ_ADDR;
                else
                    pc_write_enable <= '1';
                    pc_in_sig <= inc16(pc_out_sig);
                    state_next <= S_READ_IMM_HI;
                end if;
                end if;

            when S_READ_IMM_HI =>
                mem_addr <= pc_out_sig;
                mem_read <= '1';

                if mem_ready = '0' then
                    state_next <= S_READ_IMM_HI;
                else
                if opcode_reg = x"01" or opcode_reg = x"11" or opcode_reg = x"21" then
                    pair_write_enable <= '1';
                    pair_write_sel <= opcode_reg(5 downto 4);
                    pair_write_data <= mem_data_in & imm_lo_reg;
                    pc_write_enable <= '1';
                    pc_in_sig <= inc16(pc_out_sig);
                    instr_complete <= '1';
                    state_next <= S_FETCH;
                elsif opcode_reg = x"31" then
                    sp_write_enable <= '1';
                    sp_in_sig <= mem_data_in & imm_lo_reg;
                    pc_write_enable <= '1';
                    pc_in_sig <= inc16(pc_out_sig);
                    instr_complete <= '1';
                    state_next <= S_FETCH;
                elsif opcode_reg = x"C3" then
                    pc_write_enable <= '1';
                    pc_in_sig <= mem_data_in & imm_lo_reg;
                    instr_complete <= '1';
                    state_next <= S_FETCH;
                elsif opcode_reg = x"C2" or opcode_reg = x"CA" or
                      opcode_reg = x"D2" or opcode_reg = x"DA" then
                    pc_write_enable <= '1';
                    if condition_met(opcode_reg, flags_sig) = '1' then
                        pc_in_sig <= mem_data_in & imm_lo_reg;
                    else
                        pc_in_sig <= inc16(pc_out_sig);
                    end if;
                    instr_complete <= '1';
                    state_next <= S_FETCH;
                elsif opcode_reg = x"CD" then
                    pc_write_enable <= '1';
                    pc_in_sig <= inc16(pc_out_sig);
                    state_next <= S_CALL_PUSH_HI;
                elsif opcode_reg = x"08" then
                    pc_write_enable <= '1';
                    pc_in_sig <= inc16(pc_out_sig);
                    state_next <= S_MEM_WRITE_SP_LO;
                elsif opcode_reg = x"C4" or opcode_reg = x"CC" or
                      opcode_reg = x"D4" or opcode_reg = x"DC" then
                    pc_write_enable <= '1';
                    pc_in_sig <= inc16(pc_out_sig);
                    if condition_met(opcode_reg, flags_sig) = '1' then
                        state_next <= S_CALL_PUSH_HI;
                    else
                        instr_complete <= '1';
                        state_next <= S_FETCH;
                    end if;
                elsif opcode_reg = x"EA" then
                    pc_write_enable <= '1';
                    pc_in_sig <= inc16(pc_out_sig);
                    state_next <= S_MEM_WRITE_ADDR;
                elsif opcode_reg = x"FA" then
                    pc_write_enable <= '1';
                    pc_in_sig <= inc16(pc_out_sig);
                    state_next <= S_MEM_READ_ADDR;
                else
                    pc_write_enable <= '1';
                    pc_in_sig <= inc16(pc_out_sig);
                    instr_complete <= '1';
                    state_next <= S_FETCH;
                end if;
                end if;

            when S_MEM_READ_HL =>
                mem_addr <= hl_sig;
                mem_read <= '1';
                if mem_ready = '0' then
                    state_next <= S_MEM_READ_HL;
                else
                if dec_class = DEC_CLASS_ALU_R then
                    alu_a_sig <= a_sig;
                    alu_b_sig <= mem_data_in;
                    alu_op_sig <= dec_alu_op;
                    if dec_alu_op /= ALU_OP_CP then
                        reg_write_enable <= '1';
                        reg_write_sel <= CPU_REG_A;
                        reg_write_data <= alu_result_sig;
                    end if;
                    flags_write_enable <= '1';
                    flags_in_sig <= alu_flags_sig;
                    instr_complete <= '1';
                    state_next <= S_FETCH;
                elsif dec_class = DEC_CLASS_INC_R or dec_class = DEC_CLASS_DEC_R then
                    alu_a_sig <= mem_data_in;
                    alu_b_sig <= x"01";
                    alu_op_sig <= dec_alu_op;
                    flags_write_enable <= '1';
                    flags_in_sig <= alu_flags_sig;
                    state_next <= S_MEM_RMW_WRITE_HL;
                else
                    reg_write_enable <= '1';
                    reg_write_sel <= dec_dst;
                    reg_write_data <= mem_data_in;
                    instr_complete <= '1';
                    state_next <= S_FETCH;
                end if;
                end if;

            when S_MEM_WRITE_HL =>
                mem_addr <= hl_sig;
                if opcode_reg = x"36" then
                    mem_data_out <= imm_lo_reg;
                else
                    mem_data_out <= reg_read_data_b;
                end if;
                mem_write <= '1';
                instr_complete <= '1';
                state_next <= S_FETCH;

            when S_MEM_RMW_WRITE_HL =>
                mem_addr <= hl_sig;
                mem_data_out <= mem_rmw_data_reg;
                mem_write <= '1';
                instr_complete <= '1';
                state_next <= S_FETCH;

            when S_CB_READ_HL =>
                mem_addr <= hl_sig;
                mem_read <= '1';
                if mem_ready = '0' then
                    state_next <= S_CB_READ_HL;
                else
                    cb_result_v := cb_exec_result(imm_lo_reg, mem_data_in,
                                                  flags_sig(CPU_FLAG_C_BIT));
                    cb_flags_v := cb_exec_flags(imm_lo_reg, mem_data_in,
                                                cb_result_v, flags_sig);
                    if imm_lo_reg(7 downto 6) /= "10" and imm_lo_reg(7 downto 6) /= "11" then
                        flags_write_enable <= '1';
                        flags_in_sig <= cb_flags_v;
                    end if;
                    if imm_lo_reg(7 downto 6) = "01" then
                        instr_complete <= '1';
                        state_next <= S_FETCH;
                    else
                        state_next <= S_CB_WRITE_HL;
                    end if;
                end if;

            when S_CB_WRITE_HL =>
                mem_addr <= hl_sig;
                mem_data_out <= cb_result_reg;
                mem_write <= '1';
                instr_complete <= '1';
                state_next <= S_FETCH;

            when S_MEM_READ_REG_ADDR =>
                mem_addr <= reg_addr_v;
                mem_read <= '1';
                if mem_ready = '0' then
                    state_next <= S_MEM_READ_REG_ADDR;
                else
                reg_write_enable <= '1';
                reg_write_sel <= CPU_REG_A;
                reg_write_data <= mem_data_in;
                if opcode_reg = x"2A" then
                    pair_write_enable <= '1';
                    pair_write_sel <= CPU_PAIR_HL;
                    pair_write_data <= inc16(hl_sig);
                elsif opcode_reg = x"3A" then
                    pair_write_enable <= '1';
                    pair_write_sel <= CPU_PAIR_HL;
                    pair_write_data <= dec16(hl_sig);
                end if;
                instr_complete <= '1';
                state_next <= S_FETCH;
                end if;

            when S_MEM_WRITE_REG_ADDR =>
                mem_addr <= reg_addr_v;
                mem_data_out <= a_sig;
                mem_write <= '1';
                if opcode_reg = x"22" then
                    pair_write_enable <= '1';
                    pair_write_sel <= CPU_PAIR_HL;
                    pair_write_data <= inc16(hl_sig);
                elsif opcode_reg = x"32" then
                    pair_write_enable <= '1';
                    pair_write_sel <= CPU_PAIR_HL;
                    pair_write_data <= dec16(hl_sig);
                end if;
                instr_complete <= '1';
                state_next <= S_FETCH;

            when S_MEM_READ_ADDR =>
                mem_addr <= addr_tmp_reg;
                mem_read <= '1';
                if mem_ready = '0' then
                    state_next <= S_MEM_READ_ADDR;
                else
                reg_write_enable <= '1';
                reg_write_sel <= CPU_REG_A;
                reg_write_data <= mem_data_in;
                instr_complete <= '1';
                state_next <= S_FETCH;
                end if;

            when S_MEM_WRITE_ADDR =>
                mem_addr <= addr_tmp_reg;
                mem_data_out <= a_sig;
                mem_write <= '1';
                instr_complete <= '1';
                state_next <= S_FETCH;

            when S_MEM_WRITE_SP_LO =>
                mem_addr <= addr_tmp_reg;
                mem_data_out <= sp_out_sig(7 downto 0);
                mem_write <= '1';
                state_next <= S_MEM_WRITE_SP_HI;

            when S_MEM_WRITE_SP_HI =>
                mem_addr <= inc16(addr_tmp_reg);
                mem_data_out <= sp_out_sig(15 downto 8);
                mem_write <= '1';
                instr_complete <= '1';
                state_next <= S_FETCH;

            when S_INT_PUSH_HI =>
                mem_addr <= dec16(sp_out_sig);
                mem_data_out <= pc_out_sig(15 downto 8);
                mem_write <= '1';
                sp_write_enable <= '1';
                sp_in_sig <= dec16(sp_out_sig);
                state_next <= S_INT_PUSH_LO;

            when S_INT_PUSH_LO =>
                mem_addr <= dec16(sp_out_sig);
                mem_data_out <= pc_out_sig(7 downto 0);
                mem_write <= '1';
                sp_write_enable <= '1';
                sp_in_sig <= dec16(sp_out_sig);
                pc_write_enable <= '1';
                pc_in_sig <= interrupt_address(interrupt_vector_reg);
                interrupt_ack <= '1';
                interrupt_vector <= interrupt_vector_reg;
                state_next <= S_FETCH;

            when S_PUSH_HI =>
                mem_addr <= dec16(sp_out_sig);
                mem_data_out <= push_value_v(15 downto 8);
                mem_write <= '1';
                sp_write_enable <= '1';
                sp_in_sig <= dec16(sp_out_sig);
                state_next <= S_PUSH_LO;

            when S_PUSH_LO =>
                mem_addr <= dec16(sp_out_sig);
                mem_data_out <= push_value_v(7 downto 0);
                mem_write <= '1';
                sp_write_enable <= '1';
                sp_in_sig <= dec16(sp_out_sig);
                instr_complete <= '1';
                state_next <= S_FETCH;

            when S_POP_LO =>
                mem_addr <= sp_out_sig;
                mem_read <= '1';
                if mem_ready = '0' then
                    state_next <= S_POP_LO;
                else
                sp_write_enable <= '1';
                sp_in_sig <= inc16(sp_out_sig);
                state_next <= S_POP_HI;
                end if;

            when S_POP_HI =>
                mem_addr <= sp_out_sig;
                mem_read <= '1';
                if mem_ready = '0' then
                    state_next <= S_POP_HI;
                else
                sp_write_enable <= '1';
                sp_in_sig <= inc16(sp_out_sig);
                pair_write_enable <= '1';
                pair_write_sel <= opcode_pair_v;
                pair_write_data <= mem_data_in & stack_lo_reg;
                instr_complete <= '1';
                state_next <= S_FETCH;
                end if;

            when S_CALL_PUSH_HI =>
                mem_addr <= dec16(sp_out_sig);
                mem_data_out <= pc_out_sig(15 downto 8);
                mem_write <= '1';
                sp_write_enable <= '1';
                sp_in_sig <= dec16(sp_out_sig);
                state_next <= S_CALL_PUSH_LO;

            when S_CALL_PUSH_LO =>
                mem_addr <= dec16(sp_out_sig);
                mem_data_out <= pc_out_sig(7 downto 0);
                mem_write <= '1';
                sp_write_enable <= '1';
                sp_in_sig <= dec16(sp_out_sig);
                pc_write_enable <= '1';
                if is_rst_opcode(opcode_reg) = '1' then
                    pc_in_sig <= rst_vector(opcode_reg);
                else
                    pc_in_sig <= addr_tmp_reg;
                end if;
                instr_complete <= '1';
                state_next <= S_FETCH;

            when S_RET_READ_LO =>
                mem_addr <= sp_out_sig;
                mem_read <= '1';
                if mem_ready = '0' then
                    state_next <= S_RET_READ_LO;
                else
                sp_write_enable <= '1';
                sp_in_sig <= inc16(sp_out_sig);
                state_next <= S_RET_READ_HI;
                end if;

            when S_RET_READ_HI =>
                mem_addr <= sp_out_sig;
                mem_read <= '1';
                if mem_ready = '0' then
                    state_next <= S_RET_READ_HI;
                else
                sp_write_enable <= '1';
                sp_in_sig <= inc16(sp_out_sig);
                pc_write_enable <= '1';
                pc_in_sig <= mem_data_in & stack_lo_reg;
                instr_complete <= '1';
                state_next <= S_FETCH;
                end if;

            when S_HALT =>
                if pending_interrupt_sig = '1' then
                    state_next <= S_FETCH;
                else
                    state_next <= S_HALT;
                end if;

            when others =>
                state_next <= S_FETCH;
        end case;
    end process p_control;

    halted <= halted_reg;
    ime_out <= ime_reg;
    interrupt_pending <= pending_interrupt_sig;
    unsupported_opcode <= unsupported_reg;

    debug_a <= a_sig;
    debug_f <= f_sig;
    debug_b <= b_sig;
    debug_c <= c_sig;
    debug_d <= d_sig;
    debug_e <= e_sig;
    debug_h <= h_sig;
    debug_l <= l_sig;
    debug_pc <= pc_out_sig;
    debug_sp <= sp_out_sig;
    debug_state <= state_to_slv(state_reg);

end architecture rtl;
