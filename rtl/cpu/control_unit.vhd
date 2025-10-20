library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gb_types_pkg.all;

entity control_unit is
  port (
    clk     : in  std_logic;
    reset   : in  std_logic;

    -- Interface com memória externa
    data_in : in  u8;
    data_out: out u8;
    addr    : out u16;
    rd      : out std_logic;
    wr      : out std_logic;

    -- Interface com Register File
    q_a,q_b,q_c,q_d,q_e,q_h,q_l : in  u8;
    q_pc : in u16; q_sp : in u16; q_ir : in u8; q_ime : in std_logic;
    q_flags : in flags_t;

    we_a,we_b,we_c,we_d,we_e,we_h,we_l,we_f : out std_logic;
    din_a,din_b,din_c,din_d,din_e,din_h,din_l : out u8;
    din_flags : out flags_t;
    we_pc : out std_logic; din_pc : out u16;
    we_sp : out std_logic; din_sp : out u16;
    we_ir : out std_logic; din_ir : out u8;

    -- ALU
    alu_op : out alu_op_t;
    alu_a  : out u8; alu_b : out u8; cin : out std_logic;
    alu_y  : in  u8; flags_from_alu : in flags_t;

    -- IDU (endereços)
    inc_pc : out std_logic; inc_sp : out std_logic; dec_sp : out std_logic; inc_hl : out std_logic; dec_hl : out std_logic;
    idu_addr_sel : out addr_sel_t;
    idu_load_pc  : out std_logic; idu_pc_value : out u16;
    idu_load_sp  : out std_logic; idu_sp_value : out u16;
    idu_load_hl  : out std_logic; idu_hl_value : out u16;
    idu_addr     : in  u16;
    idu_next_pc  : in  u16;
    idu_next_sp  : in  u16;
    idu_next_hl  : in  u16;

    -- Interrupções
    irq_req    : in  std_logic;
    irq_vector : in  u16;
    irq_ack    : out std_logic;

    -- Estado de HALT (stub)
    halted  : out std_logic
  );
end entity;

architecture rtl of control_unit is
  type state_t is (
    S_RESET,
    S_IRQ_CHECK,
    S_IRQ_SERVICE,
    S_FETCH,
    S_DECODE,
    S_READ_IMM,
    S_MEM_RD_HL,
    S_MEM_WR_HL,
    S_ALU_PREP,
    S_ALU_WRITE,
    S_HALT
  );

  type micro_op_t is (
    EXEC_NONE,
    EXEC_INC_A,
    EXEC_DEC_A,
    EXEC_ADD_A_A,
    EXEC_ADC_A_A,
    EXEC_SUB_A_A,
    EXEC_SBC_A_A,
    EXEC_AND_A_A,
    EXEC_OR_A_A,
    EXEC_XOR_A_A,
    EXEC_ADD_A_IMM,
    EXEC_ADC_A_IMM,
    EXEC_SUB_A_IMM,
    EXEC_SBC_A_IMM,
    EXEC_AND_A_IMM,
    EXEC_OR_A_IMM,
    EXEC_XOR_A_IMM,
    EXEC_CP_IMM,
    EXEC_INC_MEM_HL,
    EXEC_DEC_MEM_HL
  );

  signal st : state_t := S_RESET;
  signal current_op : micro_op_t := EXEC_NONE;
  signal operand_reg : u8 := (others => '0');
  signal pending_reg_imm : reg_sel_t := REG_NONE;
  signal pending_mem_load : reg_sel_t := REG_NONE;
  signal alu_target_r : alu_dest_t := ALU_DEST_NONE;

  signal data_out_r : u8 := (others => '0');
  signal addr_r     : u16 := (others => '0');
  signal rd_r, wr_r : std_logic := '0';
  signal halted_r   : std_logic := '0';
  signal irq_ack_r  : std_logic := '0';

  signal we_a_r,we_b_r,we_c_r,we_d_r,we_e_r,we_h_r,we_l_r,we_f_r : std_logic := '0';
  signal din_a_r,din_b_r,din_c_r,din_d_r,din_e_r,din_h_r,din_l_r : u8 := (others => '0');
  signal din_flags_r : flags_t := (z=>'0', n=>'0', h=>'0', c=>'0');
  signal we_pc_r,we_sp_r,we_ir_r : std_logic := '0';
  signal din_pc_r : u16 := (others => '0');
  signal din_sp_r : u16 := (others => '0');
  signal din_ir_r : u8 := (others => '0');

  signal alu_op_r : alu_op_t := ALU_NOP;
  signal alu_a_r, alu_b_r : u8 := (others => '0');
  signal cin_r : std_logic := '0';
  signal inc_pc_r, inc_sp_r, dec_sp_r, inc_hl_r, dec_hl_r : std_logic := '0';
  signal idu_addr_sel_r : addr_sel_t := ADDR_SEL_PC;
  signal idu_load_pc_r, idu_load_sp_r, idu_load_hl_r : std_logic := '0';
  signal idu_pc_value_r, idu_sp_value_r, idu_hl_value_r : u16 := (others => '0');

begin
  data_out <= data_out_r;
  addr     <= addr_r;
  rd       <= rd_r;
  wr       <= wr_r;
  halted   <= halted_r;
  irq_ack  <= irq_ack_r;

  we_a <= we_a_r; we_b <= we_b_r; we_c <= we_c_r; we_d <= we_d_r; we_e <= we_e_r; we_h <= we_h_r; we_l <= we_l_r; we_f <= we_f_r;
  din_a <= din_a_r; din_b <= din_b_r; din_c <= din_c_r; din_d <= din_d_r; din_e <= din_e_r; din_h <= din_h_r; din_l <= din_l_r;
  din_flags <= din_flags_r;
  we_pc <= we_pc_r; we_sp <= we_sp_r; we_ir <= we_ir_r;
  din_pc <= din_pc_r; din_sp <= din_sp_r; din_ir <= din_ir_r;

  alu_op <= alu_op_r; alu_a <= alu_a_r; alu_b <= alu_b_r; cin <= cin_r;
  inc_pc <= inc_pc_r; inc_sp <= inc_sp_r; dec_sp <= dec_sp_r; inc_hl <= inc_hl_r; dec_hl <= dec_hl_r;
  idu_addr_sel <= idu_addr_sel_r;
  idu_load_pc  <= idu_load_pc_r;  idu_pc_value <= idu_pc_value_r;
  idu_load_sp  <= idu_load_sp_r;  idu_sp_value <= idu_sp_value_r;
  idu_load_hl  <= idu_load_hl_r;  idu_hl_value <= idu_hl_value_r;

  process(clk)
  begin
    if rising_edge(clk) then
      if reset='1' then
        st <= S_RESET;
        data_out_r <= (others => '0'); addr_r <= (others => '0'); rd_r <= '0'; wr_r <= '0';
        halted_r <= '0'; irq_ack_r <= '0';
        we_a_r <= '0'; we_b_r <= '0'; we_c_r <= '0'; we_d_r <= '0'; we_e_r <= '0'; we_h_r <= '0'; we_l_r <= '0'; we_f_r <= '0';
        din_a_r <= (others => '0'); din_b_r <= (others => '0'); din_c_r <= (others => '0'); din_d_r <= (others => '0');
        din_e_r <= (others => '0'); din_h_r <= (others => '0'); din_l_r <= (others => '0');
        din_flags_r <= (z=>'0', n=>'0', h=>'0', c=>'0');
        we_pc_r <= '0'; we_sp_r <= '0'; we_ir_r <= '0';
        din_pc_r <= (others => '0'); din_sp_r <= (others => '0'); din_ir_r <= (others => '0');
        alu_op_r <= ALU_NOP; alu_a_r <= (others => '0'); alu_b_r <= (others => '0'); cin_r <= '0';
        inc_pc_r <= '0'; inc_sp_r <= '0'; dec_sp_r <= '0'; inc_hl_r <= '0'; dec_hl_r <= '0';
        idu_addr_sel_r <= ADDR_SEL_PC;
        idu_load_pc_r <= '0'; idu_load_sp_r <= '0'; idu_load_hl_r <= '0';
        idu_pc_value_r <= (others => '0'); idu_sp_value_r <= (others => '0'); idu_hl_value_r <= (others => '0');
        current_op <= EXEC_NONE; operand_reg <= (others => '0');
        pending_reg_imm <= REG_NONE; pending_mem_load <= REG_NONE;
        alu_target_r <= ALU_DEST_NONE;
      else
        -- defaults a cada ciclo
        data_out_r <= (others => '0');
        addr_r     <= idu_addr;
        rd_r       <= '0';
        wr_r       <= '0';
        halted_r   <= '0';
        irq_ack_r  <= '0';

        we_a_r <= '0'; we_b_r <= '0'; we_c_r <= '0'; we_d_r <= '0'; we_e_r <= '0'; we_h_r <= '0'; we_l_r <= '0'; we_f_r <= '0';
        din_a_r <= q_a; din_b_r <= q_b; din_c_r <= q_c; din_d_r <= q_d; din_e_r <= q_e; din_h_r <= q_h; din_l_r <= q_l;
        din_flags_r <= q_flags;
        we_pc_r <= '0'; we_sp_r <= '0'; we_ir_r <= '0';
        din_pc_r <= q_pc; din_sp_r <= q_sp; din_ir_r <= q_ir;

        inc_pc_r <= '0'; inc_sp_r <= '0'; dec_sp_r <= '0'; inc_hl_r <= '0'; dec_hl_r <= '0';
        idu_addr_sel_r <= ADDR_SEL_PC;
        idu_load_pc_r <= '0'; idu_load_sp_r <= '0'; idu_load_hl_r <= '0';
        idu_pc_value_r <= q_pc; idu_sp_value_r <= q_sp; idu_hl_value_r <= q_h & q_l;

        case st is
          when S_RESET =>
            idu_addr_sel_r <= ADDR_SEL_PC;
            idu_load_pc_r <= '1';
            idu_pc_value_r <= (others => '0');
            we_pc_r <= '1';
            din_pc_r <= (others => '0');
            we_ir_r <= '1';
            din_ir_r <= (others => '0');
            current_op <= EXEC_NONE;
            operand_reg <= (others => '0');
            pending_reg_imm <= REG_NONE;
            pending_mem_load <= REG_NONE;
            alu_target_r <= ALU_DEST_NONE;
            st <= S_IRQ_CHECK;

          when S_IRQ_CHECK =>
            if irq_req = '1' then
              st <= S_IRQ_SERVICE;
            else
              st <= S_FETCH;
            end if;

          when S_IRQ_SERVICE =>
            irq_ack_r <= '1';
            idu_addr_sel_r <= ADDR_SEL_PC;
            idu_load_pc_r <= '1';
            idu_pc_value_r <= irq_vector;
            we_pc_r <= '1';
            din_pc_r <= irq_vector;
            we_ir_r <= '1';
            din_ir_r <= (others => '0');
            current_op <= EXEC_NONE;
            operand_reg <= (others => '0');
            pending_reg_imm <= REG_NONE;
            pending_mem_load <= REG_NONE;
            alu_target_r <= ALU_DEST_NONE;
            st <= S_FETCH;

          when S_FETCH =>
            idu_addr_sel_r <= ADDR_SEL_PC;
            rd_r <= '1';
            we_ir_r <= '1';
            din_ir_r <= data_in;
            inc_pc_r <= '1';
            we_pc_r <= '1';
            din_pc_r <= idu_next_pc;
            st <= S_DECODE;

          when S_DECODE =>
            current_op <= EXEC_NONE;
            pending_reg_imm <= REG_NONE;
            pending_mem_load <= REG_NONE;
            alu_target_r <= ALU_DEST_NONE;
            case q_ir is
              when x"00" =>
                st <= S_IRQ_CHECK; -- NOP
              when x"76" =>
                st <= S_HALT;
              when x"3E" =>
                pending_reg_imm <= REG_A;
                st <= S_READ_IMM;
              when x"3C" =>
                current_op <= EXEC_INC_A;
                st <= S_ALU_PREP;
              when x"3D" =>
                current_op <= EXEC_DEC_A;
                st <= S_ALU_PREP;
              when x"87" =>
                current_op <= EXEC_ADD_A_A;
                st <= S_ALU_PREP;
              when x"8F" =>
                current_op <= EXEC_ADC_A_A;
                st <= S_ALU_PREP;
              when x"97" =>
                current_op <= EXEC_SUB_A_A;
                st <= S_ALU_PREP;
              when x"9F" =>
                current_op <= EXEC_SBC_A_A;
                st <= S_ALU_PREP;
              when x"A7" =>
                current_op <= EXEC_AND_A_A;
                st <= S_ALU_PREP;
              when x"AF" =>
                current_op <= EXEC_XOR_A_A;
                st <= S_ALU_PREP;
              when x"B7" =>
                current_op <= EXEC_OR_A_A;
                st <= S_ALU_PREP;
              when x"C6" =>
                current_op <= EXEC_ADD_A_IMM;
                st <= S_READ_IMM;
              when x"CE" =>
                current_op <= EXEC_ADC_A_IMM;
                st <= S_READ_IMM;
              when x"D6" =>
                current_op <= EXEC_SUB_A_IMM;
                st <= S_READ_IMM;
              when x"DE" =>
                current_op <= EXEC_SBC_A_IMM;
                st <= S_READ_IMM;
              when x"E6" =>
                current_op <= EXEC_AND_A_IMM;
                st <= S_READ_IMM;
              when x"EE" =>
                current_op <= EXEC_XOR_A_IMM;
                st <= S_READ_IMM;
              when x"F6" =>
                current_op <= EXEC_OR_A_IMM;
                st <= S_READ_IMM;
              when x"FE" =>
                current_op <= EXEC_CP_IMM;
                st <= S_READ_IMM;
              when x"06" =>
                pending_reg_imm <= REG_B;
                st <= S_READ_IMM;
              when x"0E" =>
                pending_reg_imm <= REG_C;
                st <= S_READ_IMM;
              when x"16" =>
                pending_reg_imm <= REG_D;
                st <= S_READ_IMM;
              when x"1E" =>
                pending_reg_imm <= REG_E;
                st <= S_READ_IMM;
              when x"26" =>
                pending_reg_imm <= REG_H;
                st <= S_READ_IMM;
              when x"2E" =>
                pending_reg_imm <= REG_L;
                st <= S_READ_IMM;
              when x"47" =>
                we_b_r <= '1';
                din_b_r <= q_a;
                st <= S_IRQ_CHECK;
              when x"78" =>
                we_a_r <= '1';
                din_a_r <= q_b;
                st <= S_IRQ_CHECK;
              when x"7E" =>
                pending_mem_load <= REG_A;
                st <= S_MEM_RD_HL;
              when x"77" =>
                operand_reg <= q_a;
                st <= S_MEM_WR_HL;
              when x"23" =>
                inc_hl_r <= '1';
                we_h_r <= '1';
                we_l_r <= '1';
                din_h_r <= idu_next_hl(15 downto 8);
                din_l_r <= idu_next_hl(7 downto 0);
                st <= S_IRQ_CHECK;
              when x"2B" =>
                dec_hl_r <= '1';
                we_h_r <= '1';
                we_l_r <= '1';
                din_h_r <= idu_next_hl(15 downto 8);
                din_l_r <= idu_next_hl(7 downto 0);
                st <= S_IRQ_CHECK;
              when x"34" =>
                current_op <= EXEC_INC_MEM_HL;
                st <= S_MEM_RD_HL;
              when x"35" =>
                current_op <= EXEC_DEC_MEM_HL;
                st <= S_MEM_RD_HL;
              when others =>
                st <= S_IRQ_CHECK; -- TODO: expand
            end case;

          when S_READ_IMM =>
            idu_addr_sel_r <= ADDR_SEL_PC;
            rd_r <= '1';
            inc_pc_r <= '1';
            we_pc_r <= '1';
            din_pc_r <= idu_next_pc;
            operand_reg <= data_in;
            if pending_reg_imm /= REG_NONE then
              case pending_reg_imm is
                when REG_A =>
                  we_a_r <= '1';
                  din_a_r <= data_in;
                when REG_B =>
                  we_b_r <= '1';
                  din_b_r <= data_in;
                when REG_C =>
                  we_c_r <= '1';
                  din_c_r <= data_in;
                when REG_D =>
                  we_d_r <= '1';
                  din_d_r <= data_in;
                when REG_E =>
                  we_e_r <= '1';
                  din_e_r <= data_in;
                when REG_H =>
                  we_h_r <= '1';
                  din_h_r <= data_in;
                when REG_L =>
                  we_l_r <= '1';
                  din_l_r <= data_in;
                when others =>
                  null;
              end case;
              pending_reg_imm <= REG_NONE;
              st <= S_IRQ_CHECK;
            elsif current_op /= EXEC_NONE then
              st <= S_ALU_PREP;
            else
              st <= S_IRQ_CHECK;
            end if;

          when S_MEM_RD_HL =>
            idu_addr_sel_r <= ADDR_SEL_HL;
            rd_r <= '1';
            operand_reg <= data_in;
            if pending_mem_load /= REG_NONE then
              case pending_mem_load is
                when REG_A =>
                  we_a_r <= '1';
                  din_a_r <= data_in;
                when REG_B =>
                  we_b_r <= '1';
                  din_b_r <= data_in;
                when REG_C =>
                  we_c_r <= '1';
                  din_c_r <= data_in;
                when REG_D =>
                  we_d_r <= '1';
                  din_d_r <= data_in;
                when REG_E =>
                  we_e_r <= '1';
                  din_e_r <= data_in;
                when REG_H =>
                  we_h_r <= '1';
                  din_h_r <= data_in;
                when REG_L =>
                  we_l_r <= '1';
                  din_l_r <= data_in;
                when others =>
                  null;
              end case;
              pending_mem_load <= REG_NONE;
              st <= S_IRQ_CHECK;
            elsif current_op /= EXEC_NONE then
              st <= S_ALU_PREP;
            else
              st <= S_IRQ_CHECK;
            end if;

          when S_MEM_WR_HL =>
            idu_addr_sel_r <= ADDR_SEL_HL;
            data_out_r <= operand_reg;
            wr_r <= '1';
            st <= S_IRQ_CHECK;

          when S_ALU_PREP =>
            alu_a_r <= q_a;
            alu_b_r <= (others => '0');
            cin_r <= '0';
            alu_target_r <= ALU_DEST_A;
            case current_op is
              when EXEC_INC_A =>
                alu_op_r <= ALU_INC;
              when EXEC_DEC_A =>
                alu_op_r <= ALU_DEC;
              when EXEC_ADD_A_A =>
                alu_op_r <= ALU_ADD;
                alu_b_r <= q_a;
              when EXEC_ADC_A_A =>
                alu_op_r <= ALU_ADC;
                alu_b_r <= q_a;
                cin_r <= q_flags.c;
              when EXEC_SUB_A_A =>
                alu_op_r <= ALU_SUB;
                alu_b_r <= q_a;
              when EXEC_SBC_A_A =>
                alu_op_r <= ALU_SBC;
                alu_b_r <= q_a;
                cin_r <= q_flags.c;
              when EXEC_AND_A_A =>
                alu_op_r <= ALU_AND;
                alu_b_r <= q_a;
              when EXEC_OR_A_A =>
                alu_op_r <= ALU_OR;
                alu_b_r <= q_a;
              when EXEC_XOR_A_A =>
                alu_op_r <= ALU_XOR;
                alu_b_r <= q_a;
              when EXEC_ADD_A_IMM =>
                alu_op_r <= ALU_ADD;
                alu_b_r <= operand_reg;
              when EXEC_ADC_A_IMM =>
                alu_op_r <= ALU_ADC;
                alu_b_r <= operand_reg;
                cin_r <= q_flags.c;
              when EXEC_SUB_A_IMM =>
                alu_op_r <= ALU_SUB;
                alu_b_r <= operand_reg;
              when EXEC_SBC_A_IMM =>
                alu_op_r <= ALU_SBC;
                alu_b_r <= operand_reg;
                cin_r <= q_flags.c;
              when EXEC_AND_A_IMM =>
                alu_op_r <= ALU_AND;
                alu_b_r <= operand_reg;
              when EXEC_OR_A_IMM =>
                alu_op_r <= ALU_OR;
                alu_b_r <= operand_reg;
              when EXEC_XOR_A_IMM =>
                alu_op_r <= ALU_XOR;
                alu_b_r <= operand_reg;
              when EXEC_CP_IMM =>
                alu_op_r <= ALU_CP;
                alu_b_r <= operand_reg;
                alu_target_r <= ALU_DEST_NONE;
              when EXEC_INC_MEM_HL =>
                alu_op_r <= ALU_INC;
                alu_a_r <= operand_reg;
                alu_target_r <= ALU_DEST_MEM_HL;
              when EXEC_DEC_MEM_HL =>
                alu_op_r <= ALU_DEC;
                alu_a_r <= operand_reg;
                alu_target_r <= ALU_DEST_MEM_HL;
              when others =>
                alu_op_r <= ALU_NOP;
                alu_target_r <= ALU_DEST_NONE;
            end case;
            st <= S_ALU_WRITE;

          when S_ALU_WRITE =>
            if current_op /= EXEC_NONE then
              we_f_r <= '1';
              din_flags_r <= flags_from_alu;
            end if;
            case alu_target_r is
              when ALU_DEST_A =>
                we_a_r <= '1';
                din_a_r <= alu_y;
                st <= S_IRQ_CHECK;
              when ALU_DEST_MEM_HL =>
                operand_reg <= alu_y;
                st <= S_MEM_WR_HL;
              when others =>
                st <= S_IRQ_CHECK;
            end case;
            current_op <= EXEC_NONE;
            alu_target_r <= ALU_DEST_NONE;

          when S_HALT =>
            halted_r <= '1';
            if irq_req = '1' then
              st <= S_IRQ_CHECK;
            else
              st <= S_HALT;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
