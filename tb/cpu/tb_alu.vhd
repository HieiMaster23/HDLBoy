-- =============================================================================
-- Module:      tb_alu
-- Description: Testbench for the LR35902 ALU subset
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

entity tb_alu is
end entity tb_alu;

architecture sim of tb_alu is

    signal op       : std_logic_vector(3 downto 0);
    signal a_in     : std_logic_vector(7 downto 0);
    signal b_in     : std_logic_vector(7 downto 0);
    signal flags_in : std_logic_vector(3 downto 0);
    signal result   : std_logic_vector(7 downto 0);
    signal flags    : std_logic_vector(3 downto 0);

begin

    u_dut: entity work.alu
        port map (
            op       => op,
            a_in     => a_in,
            b_in     => b_in,
            flags_in => flags_in,
            result   => result,
            flags    => flags
        );

    p_stimulus: process
    begin
        report "=== tb_alu: Starting simulation ===" severity note;

        flags_in <= "0000";

        op <= ALU_OP_ADD;
        a_in <= x"0F";
        b_in <= x"01";
        wait for 10 ns;
        assert result = x"10" and flags = "0010"
            report "FAIL: ADD half-carry flags are incorrect"
            severity failure;

        op <= ALU_OP_ADD;
        a_in <= x"FF";
        b_in <= x"01";
        wait for 10 ns;
        assert result = x"00" and flags = "1011"
            report "FAIL: ADD carry/zero flags are incorrect"
            severity failure;

        op <= ALU_OP_SUB;
        a_in <= x"10";
        b_in <= x"01";
        wait for 10 ns;
        assert result = x"0F" and flags = "0110"
            report "FAIL: SUB borrow/half-borrow flags are incorrect"
            severity failure;

        op <= ALU_OP_AND;
        a_in <= x"F0";
        b_in <= x"0F";
        wait for 10 ns;
        assert result = x"00" and flags = "1010"
            report "FAIL: AND flags are incorrect"
            severity failure;

        op <= ALU_OP_XOR;
        a_in <= x"AA";
        b_in <= x"AA";
        wait for 10 ns;
        assert result = x"00" and flags = "1000"
            report "FAIL: XOR zero flags are incorrect"
            severity failure;

        flags_in <= "0001";
        op <= ALU_OP_INC;
        a_in <= x"0F";
        b_in <= x"00";
        wait for 10 ns;
        assert result = x"10" and flags = "0011"
            report "FAIL: INC must preserve carry and set half-carry"
            severity failure;

        op <= ALU_OP_DEC;
        a_in <= x"10";
        b_in <= x"00";
        wait for 10 ns;
        assert result = x"0F" and flags = "0111"
            report "FAIL: DEC must preserve carry and set half-borrow"
            severity failure;

        op <= ALU_OP_CP;
        a_in <= x"22";
        b_in <= x"22";
        wait for 10 ns;
        assert result = x"00" and flags = "1100"
            report "FAIL: CP equality flags are incorrect"
            severity failure;

        flags_in <= "0000";
        op <= ALU_OP_DAA;
        a_in <= x"0A";
        b_in <= x"00";
        wait for 10 ns;
        assert result = x"10" and flags = "0000"
            report "FAIL: DAA after addition did not adjust low BCD digit"
            severity failure;

        flags_in <= "0010";
        op <= ALU_OP_DAA;
        a_in <= x"3C";
        b_in <= x"00";
        wait for 10 ns;
        assert result = x"42" and flags = "0000"
            report "FAIL: DAA after half-carry addition is incorrect"
            severity failure;

        flags_in <= "0001";
        op <= ALU_OP_DAA;
        a_in <= x"A0";
        b_in <= x"00";
        wait for 10 ns;
        assert result = x"00" and flags = "1001"
            report "FAIL: DAA after carry addition is incorrect"
            severity failure;

        flags_in <= "0110";
        op <= ALU_OP_DAA;
        a_in <= x"0F";
        b_in <= x"00";
        wait for 10 ns;
        assert result = x"09" and flags = "0100"
            report "FAIL: DAA after subtraction is incorrect"
            severity failure;

        report "=== tb_alu: ALL TESTS PASSED ===" severity note;
        wait;
    end process p_stimulus;

end architecture sim;
