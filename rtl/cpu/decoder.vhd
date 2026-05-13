-- =============================================================================
-- Module:      decoder
-- Description: LR35902 opcode decoder for the first M3 CPU subset
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-11
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-11 - Initial M3 decoder subset
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gb_types_pkg.all;

entity decoder is
    port (
        opcode          : in  std_logic_vector(7 downto 0);
        valid           : out std_logic;
        instr_class     : out std_logic_vector(3 downto 0);
        dst_sel         : out std_logic_vector(2 downto 0);
        src_sel         : out std_logic_vector(2 downto 0);
        pair_sel        : out std_logic_vector(1 downto 0);
        alu_op          : out std_logic_vector(3 downto 0);
        immediate_bytes : out std_logic_vector(1 downto 0);
        reads_memory    : out std_logic;
        writes_memory   : out std_logic;
        writes_register : out std_logic;
        writes_flags    : out std_logic
    );
end entity decoder;

architecture rtl of decoder is
begin

    p_decode: process(opcode)
    begin
        valid           <= '1';
        instr_class     <= DEC_CLASS_UNKNOWN;
        dst_sel         <= CPU_REG_A;
        src_sel         <= CPU_REG_A;
        pair_sel        <= CPU_PAIR_BC;
        alu_op          <= ALU_OP_PASS;
        immediate_bytes <= "00";
        reads_memory    <= '0';
        writes_memory   <= '0';
        writes_register <= '0';
        writes_flags    <= '0';

        if opcode = x"00" then
            instr_class <= DEC_CLASS_NOP;

        elsif opcode = x"06" or opcode = x"0E" or opcode = x"16" or
              opcode = x"1E" or opcode = x"26" or opcode = x"2E" or
              opcode = x"3E" then
            instr_class     <= DEC_CLASS_LD_R_N;
            dst_sel         <= opcode(5 downto 3);
            immediate_bytes <= "01";
            writes_register <= '1';

        elsif opcode >= x"40" and opcode <= x"7F" and opcode /= x"76" then
            instr_class     <= DEC_CLASS_LD_R_R;
            dst_sel         <= opcode(5 downto 3);
            src_sel         <= opcode(2 downto 0);
            writes_register <= '1';
            if opcode(2 downto 0) = CPU_REG_HL_MEM then
                reads_memory <= '1';
            end if;
            if opcode(5 downto 3) = CPU_REG_HL_MEM then
                writes_memory <= '1';
                writes_register <= '0';
            end if;

        elsif opcode = x"21" or opcode = x"31" then
            instr_class     <= DEC_CLASS_LD_16_N;
            immediate_bytes <= "10";
            if opcode = x"21" then
                pair_sel <= CPU_PAIR_HL;
            else
                pair_sel <= CPU_PAIR_AF;
            end if;

        elsif opcode = x"04" or opcode = x"0C" or opcode = x"14" or
              opcode = x"1C" or opcode = x"24" or opcode = x"2C" or
              opcode = x"3C" then
            instr_class     <= DEC_CLASS_INC_R;
            dst_sel         <= opcode(5 downto 3);
            src_sel         <= opcode(5 downto 3);
            alu_op          <= ALU_OP_INC;
            writes_register <= '1';
            writes_flags    <= '1';

        elsif opcode = x"05" or opcode = x"0D" or opcode = x"15" or
              opcode = x"1D" or opcode = x"25" or opcode = x"2D" or
              opcode = x"3D" then
            instr_class     <= DEC_CLASS_DEC_R;
            dst_sel         <= opcode(5 downto 3);
            src_sel         <= opcode(5 downto 3);
            alu_op          <= ALU_OP_DEC;
            writes_register <= '1';
            writes_flags    <= '1';

        elsif opcode >= x"80" and opcode <= x"BF" then
            instr_class     <= DEC_CLASS_ALU_R;
            dst_sel         <= CPU_REG_A;
            src_sel         <= opcode(2 downto 0);
            writes_flags    <= '1';
            if opcode < x"88" then
                alu_op <= ALU_OP_ADD;
                writes_register <= '1';
            elsif opcode >= x"90" and opcode < x"98" then
                alu_op <= ALU_OP_SUB;
                writes_register <= '1';
            elsif opcode >= x"A0" and opcode < x"A8" then
                alu_op <= ALU_OP_AND;
                writes_register <= '1';
            elsif opcode >= x"A8" and opcode < x"B0" then
                alu_op <= ALU_OP_XOR;
                writes_register <= '1';
            elsif opcode >= x"B0" and opcode < x"B8" then
                alu_op <= ALU_OP_OR;
                writes_register <= '1';
            elsif opcode >= x"B8" then
                alu_op <= ALU_OP_CP;
                writes_register <= '0';
            else
                valid <= '0';
            end if;
            if opcode(2 downto 0) = CPU_REG_HL_MEM then
                reads_memory <= '1';
            end if;

        elsif opcode = x"C3" or opcode = x"18" or opcode = x"CD" or opcode = x"C9" then
            instr_class <= DEC_CLASS_JUMP;
            if opcode = x"18" then
                immediate_bytes <= "01";
            elsif opcode = x"C9" then
                immediate_bytes <= "00";
            else
                immediate_bytes <= "10";
            end if;

        elsif opcode = x"C1" or opcode = x"D1" or opcode = x"E1" or opcode = x"F1" or
              opcode = x"C5" or opcode = x"D5" or opcode = x"E5" or opcode = x"F5" then
            instr_class <= DEC_CLASS_STACK;
            pair_sel <= opcode(5 downto 4);

        elsif opcode = x"F3" or opcode = x"FB" or opcode = x"76" or opcode = x"CB" then
            instr_class <= DEC_CLASS_CONTROL;
            if opcode = x"CB" then
                immediate_bytes <= "01";
            end if;

        else
            valid <= '0';
            instr_class <= DEC_CLASS_UNKNOWN;
        end if;
    end process p_decode;

end architecture rtl;
