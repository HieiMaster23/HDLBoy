-- =============================================================================
-- Module:      registers
-- Description: LR35902 register file for A/F/B/C/D/E/H/L, SP, and PC
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-11
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-11 - Initial M3 register file
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gb_types_pkg.all;

entity registers is
    port (
        clk               : in  std_logic;
        reset             : in  std_logic;

        read_sel_a        : in  std_logic_vector(2 downto 0);
        read_sel_b        : in  std_logic_vector(2 downto 0);
        read_data_a       : out std_logic_vector(7 downto 0);
        read_data_b       : out std_logic_vector(7 downto 0);

        write_enable      : in  std_logic;
        write_sel         : in  std_logic_vector(2 downto 0);
        write_data        : in  std_logic_vector(7 downto 0);

        pair_write_enable : in  std_logic;
        pair_write_sel    : in  std_logic_vector(1 downto 0);
        pair_write_data   : in  std_logic_vector(15 downto 0);

        flags_write_enable : in  std_logic;
        flags_in           : in  std_logic_vector(3 downto 0);

        pc_write_enable   : in  std_logic;
        pc_in             : in  std_logic_vector(15 downto 0);
        pc_out            : out std_logic_vector(15 downto 0);

        sp_write_enable   : in  std_logic;
        sp_in             : in  std_logic_vector(15 downto 0);
        sp_out            : out std_logic_vector(15 downto 0);

        a_out             : out std_logic_vector(7 downto 0);
        f_out             : out std_logic_vector(7 downto 0);
        b_out             : out std_logic_vector(7 downto 0);
        c_out             : out std_logic_vector(7 downto 0);
        d_out             : out std_logic_vector(7 downto 0);
        e_out             : out std_logic_vector(7 downto 0);
        h_out             : out std_logic_vector(7 downto 0);
        l_out             : out std_logic_vector(7 downto 0);
        hl_out            : out std_logic_vector(15 downto 0);
        flags_out         : out std_logic_vector(3 downto 0)
    );
end entity registers;

architecture rtl of registers is

    signal reg_a  : std_logic_vector(7 downto 0);
    signal reg_f  : std_logic_vector(7 downto 0);
    signal reg_b  : std_logic_vector(7 downto 0);
    signal reg_c  : std_logic_vector(7 downto 0);
    signal reg_d  : std_logic_vector(7 downto 0);
    signal reg_e  : std_logic_vector(7 downto 0);
    signal reg_h  : std_logic_vector(7 downto 0);
    signal reg_l  : std_logic_vector(7 downto 0);
    signal reg_pc : std_logic_vector(15 downto 0);
    signal reg_sp : std_logic_vector(15 downto 0);

begin

    p_write: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                reg_a  <= (others => '0');
                reg_f  <= (others => '0');
                reg_b  <= (others => '0');
                reg_c  <= (others => '0');
                reg_d  <= (others => '0');
                reg_e  <= (others => '0');
                reg_h  <= (others => '0');
                reg_l  <= (others => '0');
                reg_pc <= (others => '0');
                reg_sp <= x"FFFE";
            else
                if write_enable = '1' then
                    case write_sel is
                        when CPU_REG_A =>
                            reg_a <= write_data;
                        when CPU_REG_B =>
                            reg_b <= write_data;
                        when CPU_REG_C =>
                            reg_c <= write_data;
                        when CPU_REG_D =>
                            reg_d <= write_data;
                        when CPU_REG_E =>
                            reg_e <= write_data;
                        when CPU_REG_H =>
                            reg_h <= write_data;
                        when CPU_REG_L =>
                            reg_l <= write_data;
                        when others =>
                            null;
                    end case;
                end if;

                if pair_write_enable = '1' then
                    case pair_write_sel is
                        when CPU_PAIR_BC =>
                            reg_b <= pair_write_data(15 downto 8);
                            reg_c <= pair_write_data(7 downto 0);
                        when CPU_PAIR_DE =>
                            reg_d <= pair_write_data(15 downto 8);
                            reg_e <= pair_write_data(7 downto 0);
                        when CPU_PAIR_HL =>
                            reg_h <= pair_write_data(15 downto 8);
                            reg_l <= pair_write_data(7 downto 0);
                        when others =>
                            reg_a <= pair_write_data(15 downto 8);
                            reg_f <= pair_write_data(7 downto 4) & "0000";
                    end case;
                end if;

                if flags_write_enable = '1' then
                    reg_f <= flags_in & "0000";
                end if;

                if pc_write_enable = '1' then
                    reg_pc <= pc_in;
                end if;

                if sp_write_enable = '1' then
                    reg_sp <= sp_in;
                end if;
            end if;
        end if;
    end process p_write;

    p_read_a: process(read_sel_a, reg_a, reg_b, reg_c, reg_d, reg_e, reg_h, reg_l)
    begin
        case read_sel_a is
            when CPU_REG_A =>
                read_data_a <= reg_a;
            when CPU_REG_B =>
                read_data_a <= reg_b;
            when CPU_REG_C =>
                read_data_a <= reg_c;
            when CPU_REG_D =>
                read_data_a <= reg_d;
            when CPU_REG_E =>
                read_data_a <= reg_e;
            when CPU_REG_H =>
                read_data_a <= reg_h;
            when CPU_REG_L =>
                read_data_a <= reg_l;
            when others =>
                read_data_a <= (others => '0');
        end case;
    end process p_read_a;

    p_read_b: process(read_sel_b, reg_a, reg_b, reg_c, reg_d, reg_e, reg_h, reg_l)
    begin
        case read_sel_b is
            when CPU_REG_A =>
                read_data_b <= reg_a;
            when CPU_REG_B =>
                read_data_b <= reg_b;
            when CPU_REG_C =>
                read_data_b <= reg_c;
            when CPU_REG_D =>
                read_data_b <= reg_d;
            when CPU_REG_E =>
                read_data_b <= reg_e;
            when CPU_REG_H =>
                read_data_b <= reg_h;
            when CPU_REG_L =>
                read_data_b <= reg_l;
            when others =>
                read_data_b <= (others => '0');
        end case;
    end process p_read_b;

    pc_out    <= reg_pc;
    sp_out    <= reg_sp;
    a_out     <= reg_a;
    f_out     <= reg_f;
    b_out     <= reg_b;
    c_out     <= reg_c;
    d_out     <= reg_d;
    e_out     <= reg_e;
    h_out     <= reg_h;
    l_out     <= reg_l;
    hl_out    <= reg_h & reg_l;
    flags_out <= reg_f(7 downto 4);

end architecture rtl;
