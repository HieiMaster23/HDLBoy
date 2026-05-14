-- =============================================================================
-- Module:      tb_decoder
-- Description: Testbench for first M3 LR35902 decoder subset
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-11
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gb_types_pkg.all;

entity tb_decoder is
end entity tb_decoder;

architecture sim of tb_decoder is

    signal opcode : std_logic_vector(7 downto 0);
    signal valid : std_logic;
    signal instr_class : std_logic_vector(3 downto 0);
    signal dst_sel : std_logic_vector(2 downto 0);
    signal src_sel : std_logic_vector(2 downto 0);
    signal pair_sel : std_logic_vector(1 downto 0);
    signal alu_op : std_logic_vector(3 downto 0);
    signal immediate_bytes : std_logic_vector(1 downto 0);
    signal reads_memory : std_logic;
    signal writes_memory : std_logic;
    signal writes_register : std_logic;
    signal writes_flags : std_logic;

begin

    u_dut: entity work.decoder
        port map (
            opcode => opcode,
            valid => valid,
            instr_class => instr_class,
            dst_sel => dst_sel,
            src_sel => src_sel,
            pair_sel => pair_sel,
            alu_op => alu_op,
            immediate_bytes => immediate_bytes,
            reads_memory => reads_memory,
            writes_memory => writes_memory,
            writes_register => writes_register,
            writes_flags => writes_flags
        );

    p_stimulus: process
    begin
        report "=== tb_decoder: Starting simulation ===" severity note;

        opcode <= x"00";
        wait for 10 ns;
        assert valid = '1' and instr_class = DEC_CLASS_NOP
            report "FAIL: NOP decode failed"
            severity failure;

        opcode <= x"3E";
        wait for 10 ns;
        assert valid = '1' and instr_class = DEC_CLASS_LD_R_N and
               dst_sel = CPU_REG_A and immediate_bytes = "01" and
               writes_register = '1'
            report "FAIL: LD A,n decode failed"
            severity failure;

        opcode <= x"78";
        wait for 10 ns;
        assert valid = '1' and instr_class = DEC_CLASS_LD_R_R and
               dst_sel = CPU_REG_A and src_sel = CPU_REG_B and
               writes_register = '1'
            report "FAIL: LD A,B decode failed"
            severity failure;

        opcode <= x"7E";
        wait for 10 ns;
        assert valid = '1' and reads_memory = '1'
            report "FAIL: LD A,(HL) decode failed"
            severity failure;

        opcode <= x"77";
        wait for 10 ns;
        assert valid = '1' and writes_memory = '1' and writes_register = '0'
            report "FAIL: LD (HL),A decode failed"
            severity failure;

        opcode <= x"34";
        wait for 10 ns;
        assert valid = '1' and instr_class = DEC_CLASS_INC_R and
               reads_memory = '1' and writes_memory = '1' and
               writes_flags = '1' and alu_op = ALU_OP_INC
            report "FAIL: INC (HL) decode failed"
            severity failure;

        opcode <= x"35";
        wait for 10 ns;
        assert valid = '1' and instr_class = DEC_CLASS_DEC_R and
               reads_memory = '1' and writes_memory = '1' and
               writes_flags = '1' and alu_op = ALU_OP_DEC
            report "FAIL: DEC (HL) decode failed"
            severity failure;

        opcode <= x"80";
        wait for 10 ns;
        assert valid = '1' and instr_class = DEC_CLASS_ALU_R and
               alu_op = ALU_OP_ADD and writes_flags = '1'
            report "FAIL: ADD A,B decode failed"
            severity failure;

        opcode <= x"86";
        wait for 10 ns;
        assert valid = '1' and instr_class = DEC_CLASS_ALU_R and
               alu_op = ALU_OP_ADD and reads_memory = '1' and
               src_sel = CPU_REG_HL_MEM
            report "FAIL: ADD A,(HL) decode failed"
            severity failure;

        opcode <= x"B8";
        wait for 10 ns;
        assert valid = '1' and alu_op = ALU_OP_CP and writes_register = '0'
            report "FAIL: CP B decode failed"
            severity failure;

        opcode <= x"21";
        wait for 10 ns;
        assert valid = '1' and instr_class = DEC_CLASS_LD_16_N and
               immediate_bytes = "10" and pair_sel = CPU_PAIR_HL
            report "FAIL: LD HL,nn decode failed"
            severity failure;

        opcode <= x"E0";
        wait for 10 ns;
        assert valid = '1' and instr_class = DEC_CLASS_LD_MEM and
               immediate_bytes = "01" and writes_memory = '1'
            report "FAIL: LDH (n),A decode failed"
            severity failure;

        opcode <= x"F0";
        wait for 10 ns;
        assert valid = '1' and instr_class = DEC_CLASS_LD_MEM and
               immediate_bytes = "01" and reads_memory = '1' and writes_register = '1'
            report "FAIL: LDH A,(n) decode failed"
            severity failure;

        opcode <= x"EA";
        wait for 10 ns;
        assert valid = '1' and instr_class = DEC_CLASS_LD_MEM and
               immediate_bytes = "10" and writes_memory = '1'
            report "FAIL: LD (nn),A decode failed"
            severity failure;

        opcode <= x"FA";
        wait for 10 ns;
        assert valid = '1' and instr_class = DEC_CLASS_LD_MEM and
               immediate_bytes = "10" and reads_memory = '1' and writes_register = '1'
            report "FAIL: LD A,(nn) decode failed"
            severity failure;

        opcode <= x"CD";
        wait for 10 ns;
        assert valid = '1' and instr_class = DEC_CLASS_JUMP and immediate_bytes = "10"
            report "FAIL: CALL nn decode failed"
            severity failure;

        opcode <= x"D1";
        wait for 10 ns;
        assert valid = '1' and instr_class = DEC_CLASS_STACK and pair_sel = CPU_PAIR_DE
            report "FAIL: POP DE decode failed"
            severity failure;

        opcode <= x"D9";
        wait for 10 ns;
        assert valid = '1' and instr_class = DEC_CLASS_JUMP and immediate_bytes = "00"
            report "FAIL: RETI decode failed"
            severity failure;

        opcode <= x"E8";
        wait for 10 ns;
        assert valid = '1' and instr_class = DEC_CLASS_LD_16_N and
               immediate_bytes = "01" and writes_flags = '1'
            report "FAIL: ADD SP,e decode failed"
            severity failure;

        opcode <= x"F8";
        wait for 10 ns;
        assert valid = '1' and instr_class = DEC_CLASS_LD_16_N and
               immediate_bytes = "01" and writes_flags = '1'
            report "FAIL: LD HL,SP+e decode failed"
            severity failure;

        opcode <= x"DB";
        wait for 10 ns;
        assert valid = '0' and instr_class = DEC_CLASS_UNKNOWN
            report "FAIL: unknown opcode must be marked invalid"
            severity failure;

        report "=== tb_decoder: ALL TESTS PASSED ===" severity note;
        wait;
    end process p_stimulus;

end architecture sim;
