library ieee;
use ieee.std_logic_1164.all;
use work.gb_types_pkg.all;

entity int_ctrl is
  port (
    clk     : in  std_logic;
    reset   : in  std_logic;

    -- Linhas de requisição (externas à CPU)
    irq_lines : in  std_logic_vector(4 downto 0); -- {Joypad, Serial, Timer, LCD, VBlank}

    -- Registros mapeados em IO (stub): IF/IE/IME
    we_if   : in  std_logic;  din_if : in std_logic_vector(4 downto 0);  q_if : out std_logic_vector(4 downto 0);
    we_ie   : in  std_logic;  din_ie : in std_logic_vector(4 downto 0);  q_ie : out std_logic_vector(4 downto 0);
    we_ime  : in  std_logic;  din_ime: in std_logic;                      q_ime: out std_logic;

    -- Saída consolidada para a Control Unit
    irq_req : out std_logic
  );
end entity;

architecture rtl of int_ctrl is
  signal r_if, r_ie : std_logic_vector(4 downto 0) := (others=>'0');
  signal r_ime : std_logic := '0';
begin
  process(clk)
    variable next_if, next_ie : std_logic_vector(4 downto 0);
    variable next_ime : std_logic;
  begin
    if rising_edge(clk) then
      if reset='1' then
        r_if <= (others=>'0');
        r_ie <= (others=>'0');
        r_ime <= '0';
      else
        next_if := r_if;
        next_ie := r_ie;
        next_ime := r_ime;

        if we_if='1' then
          next_if := din_if;
        end if;
        if we_ie='1' then
          next_ie := din_ie;
        end if;
        if we_ime='1' then
          next_ime := din_ime;
        end if;

        next_if := next_if or irq_lines;

        r_if <= next_if;
        r_ie <= next_ie;
        r_ime <= next_ime;
      end if;
    end if;
  end process;

  q_if <= r_if; q_ie <= r_ie; q_ime <= r_ime;
  irq_req <= '1' when (r_ime='1' and ((r_if and r_ie) /= "00000")) else '0';
end architecture;
