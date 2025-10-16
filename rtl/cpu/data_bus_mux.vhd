library ieee;
use ieee.std_logic_1164.all;
use work.gb_types_pkg.all;

entity data_bus_mux is
  port (
    sel    : in  bus_src_t;
    alu_y  : in  u8;
    reg_a  : in  u8; reg_b : in u8; reg_c : in u8; reg_d : in u8; reg_e : in u8; reg_h : in u8; reg_l : in u8;
    mem_di : in  u8;              -- dado vindo de fora (data_in)
    bus_do : out u8               -- dado colocado no barramento interno
  );
end entity;

architecture rtl of data_bus_mux is
begin
  with sel select
    bus_do <= alu_y  when BUS_SRC_ALU,
              reg_a  when BUS_SRC_REG_A,
              reg_b  when BUS_SRC_REG_B,
              reg_c  when BUS_SRC_REG_C,
              reg_d  when BUS_SRC_REG_D,
              reg_e  when BUS_SRC_REG_E,
              reg_h  when BUS_SRC_REG_H,
              reg_l  when BUS_SRC_REG_L,
              mem_di when BUS_SRC_MEM_DI,
              (others => '0') when others;
end architecture;
