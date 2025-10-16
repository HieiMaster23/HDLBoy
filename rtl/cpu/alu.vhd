library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gb_types_pkg.all;

entity alu is
  port (
    op      : in  alu_op_t;
    a       : in  u8;           -- acumulador A (ou operando 1)
    b       : in  u8;           -- operando 2
    cin     : in  std_logic;    -- carry in (para ADC/SBC)
    y       : out u8;
    flags_o : out flags_t
  );
end entity;

architecture rtl of alu is
begin
  process(op, a, b, cin)
    variable a_u, b_u : unsigned(7 downto 0);
    variable res_v    : unsigned(7 downto 0);
    variable tmp      : unsigned(8 downto 0);
    variable z_v, n_v, h_v, c_v : std_logic;
  begin
    a_u := unsigned(a);
    b_u := unsigned(b);
    res_v := a_u;
    z_v := '0'; n_v := '0'; h_v := '0'; c_v := '0';

    case op is
      when ALU_ADD =>
        tmp := ('0' & a_u) + ('0' & b_u);
        res_v := tmp(7 downto 0);
        c_v := tmp(8);
        if (to_integer(a_u(3 downto 0)) + to_integer(b_u(3 downto 0))) > 15 then
          h_v := '1';
        else
          h_v := '0';
        end if;
        n_v := '0';

      when ALU_SUB =>
        tmp := ('0' & a_u) - ('0' & b_u);
        res_v := tmp(7 downto 0);
        c_v := tmp(8); -- Em SUB no LR35902, C indica borrow; ajustar em fases futuras.
        if a_u(3 downto 0) < b_u(3 downto 0) then
          h_v := '1';
        else
          h_v := '0';
        end if;
        n_v := '1';

      when ALU_AND =>
        res_v := a_u and b_u;
        h_v := '1';
        n_v := '0';
        c_v := '0';

      when ALU_OR  =>
        res_v := a_u or b_u;
        h_v := '0';
        n_v := '0';
        c_v := '0';

      when ALU_XOR =>
        res_v := a_u xor b_u;
        h_v := '0';
        n_v := '0';
        c_v := '0';

      when ALU_CP  =>
        tmp := ('0' & a_u) - ('0' & b_u);
        res_v := a_u; -- CP não altera A
        c_v := tmp(8);
        if a_u(3 downto 0) < b_u(3 downto 0) then
          h_v := '1';
        else
          h_v := '0';
        end if;
        n_v := '1';

      when others =>
        -- ALU_NOP e placeholders retornam A
        res_v := a_u;
        h_v := '0';
        n_v := '0';
        c_v := '0';
    end case;

    if res_v = 0 then
      z_v := '1';
    else
      z_v := '0';
    end if;

    y <= std_logic_vector(res_v);
    flags_o <= (z=>z_v, n=>n_v, h=>h_v, c=>c_v);
  end process;
end architecture;
