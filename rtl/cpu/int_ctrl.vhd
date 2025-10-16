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

    -- Handshake com a Control Unit
    irq_ack    : in  std_logic;
    irq_req    : out std_logic;
    irq_vector : out u16
  );
end entity;

architecture rtl of int_ctrl is
  signal r_if, r_ie : std_logic_vector(4 downto 0) := (others=>'0');
  signal r_ime : std_logic := '0';
  signal active_mask : std_logic_vector(4 downto 0) := (others=>'0');
  signal vector_sel  : u16 := (others=>'0');

  function irq_mask(idx : natural) return std_logic_vector is
    variable mask : std_logic_vector(4 downto 0) := (others => '0');
  begin
    if idx <= 4 then
      mask(idx) := '1';
    end if;
    return mask;
  end function;

begin
  process(r_if, r_ie)
    variable pending : std_logic_vector(4 downto 0);
    variable mask_v : std_logic_vector(4 downto 0);
    variable vector_v : u16;
  begin
    pending := r_if and r_ie;
    mask_v := (others => '0');
    vector_v := (others => '0');

    if pending(0) = '1' then
      mask_v := irq_mask(0);
      vector_v := x"0040"; -- VBlank
    elsif pending(1) = '1' then
      mask_v := irq_mask(1);
      vector_v := x"0048"; -- LCD STAT
    elsif pending(2) = '1' then
      mask_v := irq_mask(2);
      vector_v := x"0050"; -- Timer
    elsif pending(3) = '1' then
      mask_v := irq_mask(3);
      vector_v := x"0058"; -- Serial
    elsif pending(4) = '1' then
      mask_v := irq_mask(4);
      vector_v := x"0060"; -- Joypad
    end if;

    active_mask <= mask_v;
    vector_sel  <= vector_v;
  end process;

  process(clk)
    variable next_if, next_ie : std_logic_vector(4 downto 0);
    variable next_ime : std_logic;
  begin
    if rising_edge(clk) then
      if reset='1' then
        r_if <= (others=>'0');
        r_ie <= (others=>'0');
        r_ime <= '1';
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

        if irq_ack = '1' and active_mask /= "00000" then
          next_if := next_if and not active_mask;
          next_ime := '0';
        end if;

        r_if <= next_if;
        r_ie <= next_ie;
        r_ime <= next_ime;
      end if;
    end if;
  end process;

  q_if <= r_if; q_ie <= r_ie; q_ime <= r_ime;
  irq_vector <= vector_sel;
  irq_req <= '1' when (r_ime='1' and active_mask /= "00000") else '0';
end architecture;
