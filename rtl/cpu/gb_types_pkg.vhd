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
    ALU_CP,
    ALU_INC,
    ALU_DEC
  );

  -- Destinos possíveis para os resultados da ALU
  type alu_dest_t is (
    ALU_DEST_NONE,
    ALU_DEST_A,
    ALU_DEST_MEM_HL
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

  -- Seleção de endereço fornecido pela unidade de endereços
  type addr_sel_t is (
    ADDR_SEL_PC,
    ADDR_SEL_HL,
    ADDR_SEL_SP
  );

  -- Seleção simples de registradores de 8 bits
  type reg_sel_t is (
    REG_NONE,
    REG_A,
    REG_B,
    REG_C,
    REG_D,
    REG_E,
    REG_H,
    REG_L,
    REG_MEM_HL
  );

end package;

package body gb_types_pkg is
end package body;
