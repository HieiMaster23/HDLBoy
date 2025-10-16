library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package gb_types_pkg is
  subtype u8  is std_logic_vector(7 downto 0);
  subtype u16 is std_logic_vector(15 downto 0);

  -- Flags do registrador F (Z N H C)
  type flags_t is record
    z : std_logic;  -- Zero
    n : std_logic;  -- Add/Sub (1 = sub)
    h : std_logic;  -- Half-carry
    c : std_logic;  -- Carry
  end record;

  -- Códigos de operações da ALU (subset Fase 1)
  type alu_op_t is (
    ALU_NOP,
    ALU_ADD,
    ALU_ADC,
    ALU_SUB,
    ALU_SBC,
    ALU_AND,
    ALU_OR,
    ALU_XOR,
    ALU_CP
  );

  -- Seletores de fonte do barramento de dados interno
  type bus_src_t is (
    BUS_SRC_NONE,
    BUS_SRC_ALU,
    BUS_SRC_REG_A,
    BUS_SRC_REG_B,
    BUS_SRC_REG_C,
    BUS_SRC_REG_D,
    BUS_SRC_REG_E,
    BUS_SRC_REG_H,
    BUS_SRC_REG_L,
    BUS_SRC_MEM_DI -- dado vindo de data_in externo
  );

end package;

package body gb_types_pkg is
end package body;
