library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gb_types_pkg.all;

entity idu is
  port (
    clk     : in  std_logic;
    reset   : in  std_logic;

    -- Entradas dos registradores 16-bit (vindos do regfile)
    pc_in   : in  u16;
    sp_in   : in  u16;
    hl_in   : in  u16;

    -- Comandos simples de incremento/decremento
    inc_pc  : in  std_logic;
    dec_sp  : in  std_logic;
    inc_hl  : in  std_logic;
    dec_hl  : in  std_logic;

    -- Saída de endereço para o bus externo
    addr_o  : out u16;

    -- Próximos valores pro regfile
    next_pc : out u16;
    next_sp : out u16;
    next_hl : out u16
  );
end entity;

architecture rtl of idu is
  signal addr_r   : u16 := (others => '0');
  signal next_pc_r: u16 := (others => '0');
  signal next_sp_r: u16 := (others => '0');
  signal next_hl_r: u16 := (others => '0');
begin
  process(clk)
    variable pc_u, sp_u, hl_u : unsigned(15 downto 0);
  begin
    if rising_edge(clk) then
      if reset = '1' then
        addr_r    <= (others => '0');
        next_pc_r <= (others => '0');
        next_sp_r <= (others => '0');
        next_hl_r <= (others => '0');
      else
        pc_u := unsigned(pc_in);
        sp_u := unsigned(sp_in);
        hl_u := unsigned(hl_in);

        if inc_pc = '1' then
          pc_u := pc_u + 1;
        end if;
        if dec_sp = '1' then
          sp_u := sp_u - 1;
        end if;
        if inc_hl = '1' then
          hl_u := hl_u + 1;
        end if;
        if dec_hl = '1' then
          hl_u := hl_u - 1;
        end if;

        next_pc_r <= std_logic_vector(pc_u);
        next_sp_r <= std_logic_vector(sp_u);
        next_hl_r <= std_logic_vector(hl_u);
        addr_r    <= std_logic_vector(pc_u);
      end if;
    end if;
  end process;

  addr_o  <= addr_r;
  next_pc <= next_pc_r;
  next_sp <= next_sp_r;
  next_hl <= next_hl_r;
end architecture;
