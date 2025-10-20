library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gb_types_pkg.all;

entity idu is
  port (
    -- Entradas dos registradores 16-bit (vindos do regfile)
    pc_in   : in  u16;
    sp_in   : in  u16;
    hl_in   : in  u16;

    -- Comandos de escrita direta
    load_pc : in  std_logic;
    pc_value: in  u16;
    load_sp : in  std_logic;
    sp_value: in  u16;
    load_hl : in  std_logic;
    hl_value: in  u16;

    -- Incrementos/decrementos simples
    inc_pc  : in  std_logic;
    inc_sp  : in  std_logic;
    dec_sp  : in  std_logic;
    inc_hl  : in  std_logic;
    dec_hl  : in  std_logic;

    -- Seleção de endereço exposto externamente
    addr_sel: in  addr_sel_t;

    -- Saída de endereço para o barramento externo
    addr_o  : out u16;

    -- Próximos valores calculados
    next_pc : out u16;
    next_sp : out u16;
    next_hl : out u16
  );
end entity;

architecture rtl of idu is
begin
  process(pc_in, sp_in, hl_in,
          load_pc, pc_value, inc_pc,
          load_sp, sp_value, inc_sp, dec_sp,
          load_hl, hl_value, inc_hl, dec_hl)
    variable pc_u, sp_u, hl_u : unsigned(15 downto 0);
  begin
    pc_u := unsigned(pc_in);
    sp_u := unsigned(sp_in);
    hl_u := unsigned(hl_in);

    if load_pc = '1' then
      pc_u := unsigned(pc_value);
    elsif inc_pc = '1' then
      pc_u := pc_u + 1;
    end if;

    if load_sp = '1' then
      sp_u := unsigned(sp_value);
    else
      if inc_sp = '1' then
        sp_u := sp_u + 1;
      end if;
      if dec_sp = '1' then
        sp_u := sp_u - 1;
      end if;
    end if;

    if load_hl = '1' then
      hl_u := unsigned(hl_value);
    else
      if inc_hl = '1' then
        hl_u := hl_u + 1;
      end if;
      if dec_hl = '1' then
        hl_u := hl_u - 1;
      end if;
    end if;

    next_pc <= std_logic_vector(pc_u);
    next_sp <= std_logic_vector(sp_u);
    next_hl <= std_logic_vector(hl_u);
  end process;

  with addr_sel select
    addr_o <= pc_in when ADDR_SEL_PC,
              hl_in when ADDR_SEL_HL,
              sp_in when ADDR_SEL_SP,
              pc_in when others;
end architecture;
