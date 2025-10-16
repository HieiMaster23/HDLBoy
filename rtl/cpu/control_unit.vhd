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
    inc_pc : out std_logic; dec_sp : out std_logic; inc_hl : out std_logic; dec_hl : out std_logic;

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
    EXEC_CP_IMM
  );

  signal st : state_t := S_RESET;
  signal current_op : micro_op_t := EXEC_NONE;
  signal imm_reg : u8 := (others => '0');
  signal ld_a_imm_pending : std_logic := '0';

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
  signal inc_pc_r, dec_sp_r, inc_hl_r, dec_hl_r : std_logic := '0';

  function inc16(val : u16) return u16 is
    variable tmp : unsigned(15 downto 0) := unsigned(val);
  begin
    tmp := tmp + 1;
    return std_logic_vector(tmp);
  end function;

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
  inc_pc <= inc_pc_r; dec_sp <= dec_sp_r; inc_hl <= inc_hl_r; dec_hl <= dec_hl_r;

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
        inc_pc_r <= '0'; dec_sp_r <= '0'; inc_hl_r <= '0'; dec_hl_r <= '0';
        current_op <= EXEC_NONE; imm_reg <= (others => '0'); ld_a_imm_pending <= '0';
      else
        -- defaults a cada ciclo
        data_out_r <= (others => '0');
        addr_r     <= q_pc;
        rd_r       <= '0';
        wr_r       <= '0';
        halted_r   <= '0';
        irq_ack_r  <= '0';

        we_a_r <= '0'; we_b_r <= '0'; we_c_r <= '0'; we_d_r <= '0'; we_e_r <= '0'; we_h_r <= '0'; we_l_r <= '0'; we_f_r <= '0';
        din_a_r <= q_a; din_b_r <= q_b; din_c_r <= q_c; din_d_r <= q_d; din_e_r <= q_e; din_h_r <= q_h; din_l_r <= q_l;
        din_flags_r <= q_flags;
        we_pc_r <= '0'; we_sp_r <= '0'; we_ir_r <= '0';
        din_pc_r <= q_pc; din_sp_r <= q_sp; din_ir_r <= q_ir;

        inc_pc_r <= '0'; dec_sp_r <= '0'; inc_hl_r <= '0'; dec_hl_r <= '0';

        case st is
          when S_RESET =>
            we_pc_r <= '1';
            din_pc_r <= (others => '0');
            we_ir_r <= '1';
            din_ir_r <= (others => '0');
            current_op <= EXEC_NONE;
            ld_a_imm_pending <= '0';
            st <= S_IRQ_CHECK;

          when S_IRQ_CHECK =>
            if irq_req = '1' then
              st <= S_IRQ_SERVICE;
            else
              st <= S_FETCH;
            end if;

          when S_IRQ_SERVICE =>
            irq_ack_r <= '1';
            we_pc_r <= '1';
            din_pc_r <= irq_vector;
            we_ir_r <= '1';
            din_ir_r <= (others => '0');
            current_op <= EXEC_NONE;
            ld_a_imm_pending <= '0';
            st <= S_FETCH;

          when S_FETCH =>
            rd_r <= '1';
            addr_r <= q_pc;
            we_ir_r <= '1';
            din_ir_r <= data_in;
            we_pc_r <= '1';
            din_pc_r <= inc16(q_pc);
            inc_pc_r <= '1';
            st <= S_DECODE;

          when S_DECODE =>
            current_op <= EXEC_NONE;
            ld_a_imm_pending <= '0';
            case q_ir is
              when x"00" =>
                st <= S_IRQ_CHECK; -- NOP
              when x"76" =>
                st <= S_HALT;
              when x"3E" =>
                ld_a_imm_pending <= '1';
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
              when others =>
                st <= S_IRQ_CHECK; -- TODO: expand
            end case;

          when S_READ_IMM =>
            rd_r <= '1';
            addr_r <= q_pc;
            we_pc_r <= '1';
            din_pc_r <= inc16(q_pc);
            inc_pc_r <= '1';
            imm_reg <= data_in;
            if ld_a_imm_pending = '1' then
              we_a_r <= '1';
              din_a_r <= data_in;
              ld_a_imm_pending <= '0';
              st <= S_IRQ_CHECK;
            elsif current_op /= EXEC_NONE then
              st <= S_ALU_PREP;
            else
              st <= S_IRQ_CHECK;
            end if;

          when S_ALU_PREP =>
            alu_a_r <= q_a;
            alu_b_r <= (others => '0');
            cin_r <= '0';
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
                alu_b_r <= imm_reg;
              when EXEC_ADC_A_IMM =>
                alu_op_r <= ALU_ADC;
                alu_b_r <= imm_reg;
                cin_r <= q_flags.c;
              when EXEC_SUB_A_IMM =>
                alu_op_r <= ALU_SUB;
                alu_b_r <= imm_reg;
              when EXEC_SBC_A_IMM =>
                alu_op_r <= ALU_SBC;
                alu_b_r <= imm_reg;
                cin_r <= q_flags.c;
              when EXEC_AND_A_IMM =>
                alu_op_r <= ALU_AND;
                alu_b_r <= imm_reg;
              when EXEC_OR_A_IMM =>
                alu_op_r <= ALU_OR;
                alu_b_r <= imm_reg;
              when EXEC_XOR_A_IMM =>
                alu_op_r <= ALU_XOR;
                alu_b_r <= imm_reg;
              when EXEC_CP_IMM =>
                alu_op_r <= ALU_CP;
                alu_b_r <= imm_reg;
              when others =>
                alu_op_r <= ALU_NOP;
            end case;
            st <= S_ALU_WRITE;

          when S_ALU_WRITE =>
            if current_op /= EXEC_CP_IMM and current_op /= EXEC_NONE then
              we_a_r <= '1';
              din_a_r <= alu_y;
            end if;
            we_f_r <= '1';
            din_flags_r <= flags_from_alu;
            current_op <= EXEC_NONE;
            st <= S_IRQ_CHECK;

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
