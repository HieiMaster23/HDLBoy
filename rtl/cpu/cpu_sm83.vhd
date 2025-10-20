library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gb_types_pkg.all;

entity cpu_sm83 is
  port (
    clk      : in  std_logic;
    reset    : in  std_logic;

    -- Barramento externo
    addr     : out u16;
    data_in  : in  u8;
    data_out : out u8;
    rd       : out std_logic;
    wr       : out std_logic;

    -- Interrupções (VBlank, LCD, Timer, Serial, Joypad)
    irq_lines : in std_logic_vector(4 downto 0)
  );
end entity;

architecture struct of cpu_sm83 is
  -- Register file wires
  signal q_a,q_b,q_c,q_d,q_e,q_h,q_l : u8;
  signal q_pc,q_sp : u16; signal q_ir : u8; signal q_ime : std_logic;
  signal q_flags : flags_t;

  signal we_a,we_b,we_c,we_d,we_e,we_h,we_l,we_f : std_logic;
  signal din_a,din_b,din_c,din_d,din_e,din_h,din_l : u8;
  signal we_pc,we_sp,we_ir : std_logic; signal din_pc,din_sp : u16; signal din_ir : u8;
  signal din_flags : flags_t;

  -- ALU
  signal alu_op  : alu_op_t; signal alu_a,alu_b,alu_y : u8; signal cin : std_logic; signal flags_from_alu : flags_t;

  -- Controle de endereços
  signal inc_pc,inc_sp,dec_sp,inc_hl,dec_hl : std_logic;
  signal idu_addr_sel : addr_sel_t;
  signal idu_load_pc, idu_load_sp, idu_load_hl : std_logic;
  signal idu_pc_value, idu_sp_value, idu_hl_value : u16;
  signal idu_addr : u16;
  signal idu_next_pc, idu_next_sp, idu_next_hl : u16;

  -- INT CTRL
  signal we_if,we_ie,we_ime : std_logic := '0';
  signal din_if,din_ie : std_logic_vector(4 downto 0) := (others=>'0');
  signal din_ime : std_logic := '0';
  signal q_if,q_ie : std_logic_vector(4 downto 0); signal q_ime_int : std_logic; signal irq_req : std_logic;
  signal irq_vector : u16; signal irq_ack : std_logic;

  -- Estado HALT
  signal halted : std_logic;
begin
  -- Register file
  u_rf: entity work.register_file
    port map (
      clk=>clk, reset=>reset,
      we_a=>we_a, din_a=>din_a,
      we_b=>we_b, din_b=>din_b,
      we_c=>we_c, din_c=>din_c,
      we_d=>we_d, din_d=>din_d,
      we_e=>we_e, din_e=>din_e,
      we_h=>we_h, din_h=>din_h,
      we_l=>we_l, din_l=>din_l,
      we_f=>we_f, din_flags=>din_flags,
      q_a=>q_a, q_b=>q_b, q_c=>q_c, q_d=>q_d, q_e=>q_e, q_h=>q_h, q_l=>q_l, q_flags=>q_flags,
      we_pc=>we_pc, din_pc=>din_pc, q_pc=>q_pc,
      we_sp=>we_sp, din_sp=>din_sp, q_sp=>q_sp,
      we_ir=>we_ir, din_ir=>din_ir, q_ir=>q_ir,
      we_ime=>'0', din_ime=>'0', q_ime=>q_ime
    );

  -- ALU
  u_alu: entity work.alu
    port map (
      op=>alu_op, a=>alu_a, b=>alu_b, cin=>cin,
      flags_in=>q_flags,
      y=>alu_y, flags_o=>flags_from_alu
    );

  -- Unidade de endereços
  u_idu: entity work.idu
    port map (
      pc_in=>q_pc,
      sp_in=>q_sp,
      hl_in=>q_h & q_l,
      load_pc=>idu_load_pc,
      pc_value=>idu_pc_value,
      load_sp=>idu_load_sp,
      sp_value=>idu_sp_value,
      load_hl=>idu_load_hl,
      hl_value=>idu_hl_value,
      inc_pc=>inc_pc,
      inc_sp=>inc_sp,
      dec_sp=>dec_sp,
      inc_hl=>inc_hl,
      dec_hl=>dec_hl,
      addr_sel=>idu_addr_sel,
      addr_o=>idu_addr,
      next_pc=>idu_next_pc,
      next_sp=>idu_next_sp,
      next_hl=>idu_next_hl
    );

  -- INT CTRL (stub funcional)
  u_int: entity work.int_ctrl
    port map (
      clk=>clk, reset=>reset,
      irq_lines=>irq_lines,
      we_if=>we_if, din_if=>din_if, q_if=>q_if,
      we_ie=>we_ie, din_ie=>din_ie, q_ie=>q_ie,
      we_ime=>we_ime, din_ime=>din_ime, q_ime=>q_ime_int,
      irq_ack=>irq_ack,
      irq_req=>irq_req,
      irq_vector=>irq_vector
    );

  -- CONTROL UNIT
  u_cu: entity work.control_unit
    port map (
      clk=>clk, reset=>reset,
      data_in=>data_in, data_out=>data_out,
      addr=>addr, rd=>rd, wr=>wr,
      q_a=>q_a, q_b=>q_b, q_c=>q_c, q_d=>q_d, q_e=>q_e, q_h=>q_h, q_l=>q_l,
      q_pc=>q_pc, q_sp=>q_sp, q_ir=>q_ir, q_ime=>q_ime_int, q_flags=>q_flags,
      we_a=>we_a, we_b=>we_b, we_c=>we_c, we_d=>we_d, we_e=>we_e, we_h=>we_h, we_l=>we_l, we_f=>we_f,
      din_a=>din_a, din_b=>din_b, din_c=>din_c, din_d=>din_d, din_e=>din_e, din_h=>din_h, din_l=>din_l,
      din_flags=>din_flags,
      we_pc=>we_pc, din_pc=>din_pc,
      we_sp=>we_sp, din_sp=>din_sp,
      we_ir=>we_ir, din_ir=>din_ir,
      alu_op=>alu_op, alu_a=>alu_a, alu_b=>alu_b, cin=>cin, alu_y=>alu_y, flags_from_alu=>flags_from_alu,
      inc_pc=>inc_pc, inc_sp=>inc_sp, dec_sp=>dec_sp, inc_hl=>inc_hl, dec_hl=>dec_hl,
      idu_addr_sel=>idu_addr_sel,
      idu_load_pc=>idu_load_pc, idu_pc_value=>idu_pc_value,
      idu_load_sp=>idu_load_sp, idu_sp_value=>idu_sp_value,
      idu_load_hl=>idu_load_hl, idu_hl_value=>idu_hl_value,
      idu_addr=>idu_addr,
      idu_next_pc=>idu_next_pc,
      idu_next_sp=>idu_next_sp,
      idu_next_hl=>idu_next_hl,
      irq_req=>irq_req,
      irq_vector=>irq_vector,
      irq_ack=>irq_ack,
      halted=>halted
    );

end architecture;
