library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gb_types_pkg.all;

entity register_file is
  port (
    clk     : in  std_logic;
    reset   : in  std_logic;

    -- Escrita em registradores de 8 bits
    we_a    : in  std_logic;  din_a : in u8;
    we_b    : in  std_logic;  din_b : in u8;
    we_c    : in  std_logic;  din_c : in u8;
    we_d    : in  std_logic;  din_d : in u8;
    we_e    : in  std_logic;  din_e : in u8;
    we_h    : in  std_logic;  din_h : in u8;
    we_l    : in  std_logic;  din_l : in u8;

    -- Flags (escrita conjunta no F)
    we_f    : in  std_logic;  din_flags : in flags_t;

    -- Leitura direta dos registradores (saídas permanentes)
    q_a     : out u8;
    q_b     : out u8;
    q_c     : out u8;
    q_d     : out u8;
    q_e     : out u8;
    q_h     : out u8;
    q_l     : out u8;
    q_flags : out flags_t;

    -- Registradores de 16 bits
    we_pc   : in  std_logic;  din_pc : in u16;  q_pc : out u16;
    we_sp   : in  std_logic;  din_sp : in u16;  q_sp : out u16;

    -- IR (instruction register) e IE (interrupt enable global)
    we_ir   : in  std_logic;  din_ir : in u8;   q_ir : out u8;
    we_ime  : in  std_logic;  din_ime: in std_logic; q_ime: out std_logic
  );
end entity;

architecture rtl of register_file is
  signal r_a, r_b, r_c, r_d, r_e, r_h, r_l : u8 := (others => '0');
  signal r_f : flags_t := (z=>'0', n=>'0', h=>'0', c=>'0');
  signal r_pc, r_sp : u16 := (others => '0');
  signal r_ir : u8 := (others => '0');
  signal r_ime: std_logic := '0';
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        r_a <= (others => '0'); r_b <= (others => '0'); r_c <= (others => '0');
        r_d <= (others => '0'); r_e <= (others => '0'); r_h <= (others => '0');
        r_l <= (others => '0'); r_f <= (z=>'0', n=>'0', h=>'0', c=>'0');
        r_pc <= (others => '0'); r_sp <= (others => '0');
        r_ir <= (others => '0'); r_ime <= '0';
      else
        if we_a='1' then r_a <= din_a; end if;
        if we_b='1' then r_b <= din_b; end if;
        if we_c='1' then r_c <= din_c; end if;
        if we_d='1' then r_d <= din_d; end if;
        if we_e='1' then r_e <= din_e; end if;
        if we_h='1' then r_h <= din_h; end if;
        if we_l='1' then r_l <= din_l; end if;
        if we_f='1' then r_f <= din_flags; end if;
        if we_pc='1' then r_pc <= din_pc; end if;
        if we_sp='1' then r_sp <= din_sp; end if;
        if we_ir='1' then r_ir <= din_ir; end if;
        if we_ime='1' then r_ime <= din_ime; end if;
      end if;
    end if;
  end process;

  q_a <= r_a; q_b <= r_b; q_c <= r_c; q_d <= r_d; q_e <= r_e; q_h <= r_h; q_l <= r_l;
  q_flags <= r_f; q_pc <= r_pc; q_sp <= r_sp; q_ir <= r_ir; q_ime <= r_ime;
end architecture;
