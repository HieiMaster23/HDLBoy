-- =============================================================================
-- Module:      alu
-- Description: LR35902 8-bit ALU subset with flag generation
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-11
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-11 - Initial M3 ALU subset
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gb_types_pkg.all;

entity alu is
    port (
        op       : in  std_logic_vector(3 downto 0);
        a_in     : in  std_logic_vector(7 downto 0);
        b_in     : in  std_logic_vector(7 downto 0);
        flags_in : in  std_logic_vector(3 downto 0);
        result   : out std_logic_vector(7 downto 0);
        flags    : out std_logic_vector(3 downto 0)
    );
end entity alu;

architecture rtl of alu is
begin

    p_alu: process(op, a_in, b_in, flags_in)
        variable a_u       : unsigned(7 downto 0);
        variable b_u       : unsigned(7 downto 0);
        variable temp9     : unsigned(8 downto 0);
        variable res_v     : unsigned(7 downto 0);
        variable flags_v   : std_logic_vector(3 downto 0);
        variable low_a     : unsigned(4 downto 0);
        variable low_b     : unsigned(4 downto 0);
        variable carry1_v   : unsigned(0 downto 0);
        variable carry5_v   : unsigned(4 downto 0);
        variable carry9_v   : unsigned(8 downto 0);
        variable daa_adjust  : unsigned(7 downto 0);
        variable daa_temp    : unsigned(8 downto 0);
        variable daa_carry   : std_logic;
    begin
        a_u := unsigned(a_in);
        b_u := unsigned(b_in);
        temp9 := (others => '0');
        res_v := a_u;
        flags_v := flags_in;
        low_a := unsigned('0' & a_in(3 downto 0));
        low_b := unsigned('0' & b_in(3 downto 0));
        if flags_in(CPU_FLAG_C_BIT) = '1' then
            carry1_v := "1";
            carry5_v := to_unsigned(1, 5);
            carry9_v := to_unsigned(1, 9);
        else
            carry1_v := "0";
            carry5_v := to_unsigned(0, 5);
        carry9_v := to_unsigned(0, 9);
        end if;
        daa_adjust := (others => '0');
        daa_temp := (others => '0');
        daa_carry := flags_in(CPU_FLAG_C_BIT);

        case op is
            when ALU_OP_ADD =>
                temp9 := ('0' & a_u) + ('0' & b_u);
                res_v := temp9(7 downto 0);
                if temp9(7 downto 0) = x"00" then
                    flags_v(CPU_FLAG_Z_BIT) := '1';
                else
                    flags_v(CPU_FLAG_Z_BIT) := '0';
                end if;
                flags_v(CPU_FLAG_N_BIT) := '0';
                if (low_a + low_b) > to_unsigned(15, 5) then
                    flags_v(CPU_FLAG_H_BIT) := '1';
                else
                    flags_v(CPU_FLAG_H_BIT) := '0';
                end if;
                flags_v(CPU_FLAG_C_BIT) := temp9(8);

            when ALU_OP_ADC =>
                temp9 := ('0' & a_u) + ('0' & b_u) + carry9_v;
                res_v := temp9(7 downto 0);
                if temp9(7 downto 0) = x"00" then
                    flags_v(CPU_FLAG_Z_BIT) := '1';
                else
                    flags_v(CPU_FLAG_Z_BIT) := '0';
                end if;
                flags_v(CPU_FLAG_N_BIT) := '0';
                if (low_a + low_b + carry5_v) > to_unsigned(15, 5) then
                    flags_v(CPU_FLAG_H_BIT) := '1';
                else
                    flags_v(CPU_FLAG_H_BIT) := '0';
                end if;
                flags_v(CPU_FLAG_C_BIT) := temp9(8);

            when ALU_OP_SUB | ALU_OP_CP =>
                res_v := a_u - b_u;
                if res_v = x"00" then
                    flags_v(CPU_FLAG_Z_BIT) := '1';
                else
                    flags_v(CPU_FLAG_Z_BIT) := '0';
                end if;
                flags_v(CPU_FLAG_N_BIT) := '1';
                if unsigned(a_in(3 downto 0)) < unsigned(b_in(3 downto 0)) then
                    flags_v(CPU_FLAG_H_BIT) := '1';
                else
                    flags_v(CPU_FLAG_H_BIT) := '0';
                end if;
                if a_u < b_u then
                    flags_v(CPU_FLAG_C_BIT) := '1';
                else
                    flags_v(CPU_FLAG_C_BIT) := '0';
                end if;

            when ALU_OP_SBC =>
                temp9 := ('0' & a_u) - ('0' & b_u) - carry9_v;
                res_v := temp9(7 downto 0);
                if res_v = x"00" then
                    flags_v(CPU_FLAG_Z_BIT) := '1';
                else
                    flags_v(CPU_FLAG_Z_BIT) := '0';
                end if;
                flags_v(CPU_FLAG_N_BIT) := '1';
                if low_a < (low_b + carry5_v) then
                    flags_v(CPU_FLAG_H_BIT) := '1';
                else
                    flags_v(CPU_FLAG_H_BIT) := '0';
                end if;
                if ('0' & a_u) < (('0' & b_u) + carry9_v) then
                    flags_v(CPU_FLAG_C_BIT) := '1';
                else
                    flags_v(CPU_FLAG_C_BIT) := '0';
                end if;

            when ALU_OP_AND =>
                res_v := a_u and b_u;
                if res_v = x"00" then
                    flags_v(CPU_FLAG_Z_BIT) := '1';
                else
                    flags_v(CPU_FLAG_Z_BIT) := '0';
                end if;
                flags_v(CPU_FLAG_N_BIT) := '0';
                flags_v(CPU_FLAG_H_BIT) := '1';
                flags_v(CPU_FLAG_C_BIT) := '0';

            when ALU_OP_OR =>
                res_v := a_u or b_u;
                if res_v = x"00" then
                    flags_v(CPU_FLAG_Z_BIT) := '1';
                else
                    flags_v(CPU_FLAG_Z_BIT) := '0';
                end if;
                flags_v(CPU_FLAG_N_BIT) := '0';
                flags_v(CPU_FLAG_H_BIT) := '0';
                flags_v(CPU_FLAG_C_BIT) := '0';

            when ALU_OP_XOR =>
                res_v := a_u xor b_u;
                if res_v = x"00" then
                    flags_v(CPU_FLAG_Z_BIT) := '1';
                else
                    flags_v(CPU_FLAG_Z_BIT) := '0';
                end if;
                flags_v(CPU_FLAG_N_BIT) := '0';
                flags_v(CPU_FLAG_H_BIT) := '0';
                flags_v(CPU_FLAG_C_BIT) := '0';

            when ALU_OP_INC =>
                res_v := a_u + 1;
                if res_v = x"00" then
                    flags_v(CPU_FLAG_Z_BIT) := '1';
                else
                    flags_v(CPU_FLAG_Z_BIT) := '0';
                end if;
                flags_v(CPU_FLAG_N_BIT) := '0';
                if a_in(3 downto 0) = x"F" then
                    flags_v(CPU_FLAG_H_BIT) := '1';
                else
                    flags_v(CPU_FLAG_H_BIT) := '0';
                end if;
                flags_v(CPU_FLAG_C_BIT) := flags_in(CPU_FLAG_C_BIT);

            when ALU_OP_DEC =>
                res_v := a_u - 1;
                if res_v = x"00" then
                    flags_v(CPU_FLAG_Z_BIT) := '1';
                else
                    flags_v(CPU_FLAG_Z_BIT) := '0';
                end if;
                flags_v(CPU_FLAG_N_BIT) := '1';
                if a_in(3 downto 0) = x"0" then
                    flags_v(CPU_FLAG_H_BIT) := '1';
                else
                    flags_v(CPU_FLAG_H_BIT) := '0';
                end if;
                flags_v(CPU_FLAG_C_BIT) := flags_in(CPU_FLAG_C_BIT);

            when ALU_OP_DAA =>
                if flags_in(CPU_FLAG_N_BIT) = '0' then
                    if flags_in(CPU_FLAG_H_BIT) = '1' or unsigned(a_in(3 downto 0)) > to_unsigned(9, 4) then
                        daa_adjust := daa_adjust + x"06";
                    end if;
                    if flags_in(CPU_FLAG_C_BIT) = '1' or a_u > x"99" then
                        daa_adjust := daa_adjust + x"60";
                        daa_carry := '1';
                    end if;
                    daa_temp := ('0' & a_u) + ('0' & daa_adjust);
                    res_v := daa_temp(7 downto 0);
                else
                    if flags_in(CPU_FLAG_H_BIT) = '1' then
                        daa_adjust := daa_adjust + x"06";
                    end if;
                    if flags_in(CPU_FLAG_C_BIT) = '1' then
                        daa_adjust := daa_adjust + x"60";
                    end if;
                    res_v := a_u - daa_adjust;
                end if;
                if res_v = x"00" then
                    flags_v(CPU_FLAG_Z_BIT) := '1';
                else
                    flags_v(CPU_FLAG_Z_BIT) := '0';
                end if;
                flags_v(CPU_FLAG_N_BIT) := flags_in(CPU_FLAG_N_BIT);
                flags_v(CPU_FLAG_H_BIT) := '0';
                flags_v(CPU_FLAG_C_BIT) := daa_carry;

            when others =>
                res_v := a_u;
                flags_v := flags_in;
        end case;

        result <= std_logic_vector(res_v);
        flags <= flags_v;
    end process p_alu;

end architecture rtl;
