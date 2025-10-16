library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gb_types_pkg.all;

entity alu is
  port (
    op       : in  alu_op_t;
    a        : in  u8;           -- acumulador A (ou operando 1)
    b        : in  u8;           -- operando 2
    cin      : in  std_logic;    -- carry in (para ADC/SBC)
    flags_in : in  flags_t;      -- flags atuais (para operações que preservam C)
    y        : out u8;
    flags_o  : out flags_t
  );
end entity;

architecture rtl of alu is
  function to_std_logic(b : boolean) return std_logic is
  begin
    if b then
      return '1';
    else
      return '0';
    end if;
  end function;

  function half_carry_add(a_nib, b_nib : unsigned(3 downto 0); carry : std_logic) return std_logic is
    variable tmp : unsigned(4 downto 0);
    variable carry_val : unsigned(4 downto 0);
  begin
    if carry = '1' then
      carry_val := "00001";
    else
      carry_val := (others => '0');
    end if;
    tmp := resize(a_nib, 5) + resize(b_nib, 5) + carry_val;
    return tmp(4);
  end function;

  function half_carry_sub(a_nib, b_nib : unsigned(3 downto 0); carry : std_logic) return std_logic is
    variable borrow : boolean;
    variable carry_int : integer := 0;
  begin
    if carry = '1' then
      carry_int := 1;
    end if;
    borrow := (to_integer(a_nib) < (to_integer(b_nib) + carry_int));
    return to_std_logic(borrow);
  end function;

begin
  process(op, a, b, cin, flags_in)
    variable a_u, b_u : unsigned(7 downto 0);
    variable result   : unsigned(7 downto 0);
    variable tmp      : unsigned(8 downto 0);
    variable carry_u  : unsigned(8 downto 0);
    variable cin_int  : integer;
    variable z_v, n_v, h_v, c_v : std_logic;
  begin
    a_u := unsigned(a);
    b_u := unsigned(b);
    result := a_u;

    z_v := flags_in.z;
    n_v := flags_in.n;
    h_v := flags_in.h;
    c_v := flags_in.c;

    if cin = '1' then
      carry_u := to_unsigned(1, 9);
      cin_int := 1;
    else
      carry_u := to_unsigned(0, 9);
      cin_int := 0;
    end if;

    case op is
      when ALU_ADD =>
        tmp := resize(a_u, 9) + resize(b_u, 9);
        result := tmp(7 downto 0);
        c_v := tmp(8);
        h_v := half_carry_add(a_u(3 downto 0), b_u(3 downto 0), '0');
        n_v := '0';

      when ALU_ADC =>
        tmp := resize(a_u, 9) + resize(b_u, 9) + carry_u;
        result := tmp(7 downto 0);
        c_v := tmp(8);
        h_v := half_carry_add(a_u(3 downto 0), b_u(3 downto 0), cin);
        n_v := '0';

      when ALU_SUB =>
        tmp := resize(a_u, 9) - resize(b_u, 9);
        result := tmp(7 downto 0);
        c_v := to_std_logic(to_integer(a_u) < to_integer(b_u));
        h_v := half_carry_sub(a_u(3 downto 0), b_u(3 downto 0), '0');
        n_v := '1';

      when ALU_SBC =>
        tmp := resize(a_u, 9) - (resize(b_u, 9) + carry_u);
        result := tmp(7 downto 0);
        c_v := to_std_logic(to_integer(a_u) < (to_integer(b_u) + cin_int));
        h_v := half_carry_sub(a_u(3 downto 0), b_u(3 downto 0), cin);
        n_v := '1';

      when ALU_AND =>
        result := a_u and b_u;
        n_v := '0';
        h_v := '1';
        c_v := '0';

      when ALU_OR =>
        result := a_u or b_u;
        n_v := '0';
        h_v := '0';
        c_v := '0';

      when ALU_XOR =>
        result := a_u xor b_u;
        n_v := '0';
        h_v := '0';
        c_v := '0';

      when ALU_CP =>
        tmp := resize(a_u, 9) - resize(b_u, 9);
        result := tmp(7 downto 0);
        c_v := to_std_logic(to_integer(a_u) < to_integer(b_u));
        h_v := half_carry_sub(a_u(3 downto 0), b_u(3 downto 0), '0');
        n_v := '1';

      when ALU_INC =>
        tmp := resize(a_u, 9) + 1;
        result := tmp(7 downto 0);
        h_v := half_carry_add(a_u(3 downto 0), "0001", '0');
        n_v := '0';
        c_v := flags_in.c;

      when ALU_DEC =>
        tmp := resize(a_u, 9) - 1;
        result := tmp(7 downto 0);
        h_v := half_carry_sub(a_u(3 downto 0), "0001", '0');
        n_v := '1';
        c_v := flags_in.c;

      when others =>
        result := a_u;
        z_v := flags_in.z;
        n_v := flags_in.n;
        h_v := flags_in.h;
        c_v := flags_in.c;
    end case;

    if result = 0 then
      z_v := '1';
    else
      z_v := '0';
    end if;

    y <= std_logic_vector(result);
    flags_o <= (z=>z_v, n=>n_v, h=>h_v, c=>c_v);
  end process;
end architecture;
