-- =============================================================================
-- Module:      timer
-- Description: DMG timer register block with divider-edge TIMA increments
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-05-14
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Revision History:
-- 2026-05-14 - Added DIV/TIMA/TMA/TAC timer core for CPU bring-up
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity timer is
    generic (
        G_DIV_COUNTER_STEP      : integer := 4;
        G_DIV_COUNTER_RESET     : integer := 4;
        G_TIMA_READ_AFTER_TICK  : boolean := true
    );
    port (
        clk                 : in  std_logic;
        reset               : in  std_logic;

        write_data          : in  std_logic_vector(7 downto 0);
        write_div           : in  std_logic;
        write_tima          : in  std_logic;
        write_tma           : in  std_logic;
        write_tac           : in  std_logic;

        div_read            : out std_logic_vector(7 downto 0);
        tima_read           : out std_logic_vector(7 downto 0);
        tma_read            : out std_logic_vector(7 downto 0);
        tac_read            : out std_logic_vector(7 downto 0);
        timer_interrupt_set : out std_logic
    );
end entity timer;

architecture rtl of timer is

    signal div_counter : unsigned(15 downto 0);
    signal tima_reg : std_logic_vector(7 downto 0);
    signal tma_reg : std_logic_vector(7 downto 0);
    signal tac_reg : std_logic_vector(2 downto 0);
    signal overflow_pending : std_logic;
    signal timer_interrupt_set_reg : std_logic;

    function timer_input(
        counter_in : unsigned(15 downto 0);
        tac_in     : std_logic_vector(2 downto 0)) return std_logic is
    begin
        if tac_in(2) = '0' then
            return '0';
        else
            case tac_in(1 downto 0) is
                when "00" =>
                    return counter_in(9); -- 4096 Hz
                when "01" =>
                    return counter_in(3); -- 262144 Hz
                when "10" =>
                    return counter_in(5); -- 65536 Hz
                when others =>
                    return counter_in(7); -- 16384 Hz
            end case;
        end if;
    end function timer_input;

    function visible_tima_after_tick(
        counter_in : unsigned(15 downto 0);
        step_in    : integer;
        tima_in    : std_logic_vector(7 downto 0);
        tma_in     : std_logic_vector(7 downto 0);
        tac_in     : std_logic_vector(2 downto 0);
        pending_in : std_logic) return std_logic_vector is
        variable div_next_v : unsigned(15 downto 0);
    begin
        div_next_v := counter_in + to_unsigned(step_in, 16);

        if pending_in = '1' then
            return tima_in;
        elsif timer_input(counter_in, tac_in) = '1' and
              timer_input(div_next_v, tac_in) = '0' then
            if tima_in = x"FF" then
                return x"00";
            else
                return std_logic_vector(unsigned(tima_in) + 1);
            end if;
        else
            return tima_in;
        end if;
    end function visible_tima_after_tick;

begin

    p_timer: process(clk)
        variable div_next_v : unsigned(15 downto 0);
        variable tac_next_v : std_logic_vector(2 downto 0);
        variable tma_next_v : std_logic_vector(7 downto 0);
        variable old_timer_input_v : std_logic;
        variable new_timer_input_v : std_logic;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                -- Match the boot-time divider phase expected by the current
                -- M-cycle CPU model used by the Blargg timing harness.
                div_counter <= to_unsigned(G_DIV_COUNTER_RESET, 16);
                tima_reg <= (others => '0');
                tma_reg <= (others => '0');
                tac_reg <= (others => '0');
                overflow_pending <= '0';
                timer_interrupt_set_reg <= '0';
            else
                timer_interrupt_set_reg <= '0';

                div_next_v := div_counter + to_unsigned(G_DIV_COUNTER_STEP, 16);
                if write_div = '1' then
                    div_next_v := (others => '0');
                end if;

                tac_next_v := tac_reg;
                if write_tac = '1' then
                    tac_next_v := write_data(2 downto 0);
                end if;

                tma_next_v := tma_reg;
                if write_tma = '1' then
                    tma_next_v := write_data;
                end if;

                old_timer_input_v := timer_input(div_counter, tac_reg);
                new_timer_input_v := timer_input(div_next_v, tac_next_v);

                div_counter <= div_next_v;
                tac_reg <= tac_next_v;
                tma_reg <= tma_next_v;

                if overflow_pending = '1' then
                    if write_tima = '1' then
                        tima_reg <= write_data;
                        overflow_pending <= '0';
                    else
                        tima_reg <= tma_next_v;
                        overflow_pending <= '0';
                        timer_interrupt_set_reg <= '1';
                    end if;
                else
                    if write_tima = '1' then
                        tima_reg <= write_data;
                    elsif old_timer_input_v = '1' and new_timer_input_v = '0' then
                        if tima_reg = x"FF" then
                            tima_reg <= x"00";
                            overflow_pending <= '1';
                        else
                            tima_reg <= std_logic_vector(unsigned(tima_reg) + 1);
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process p_timer;

    div_read <= std_logic_vector(div_counter(15 downto 8));
    -- The current CPU bus model samples reads at the end of an M-cycle. Expose
    -- the TIMA value that is visible after the timer edge of that same M-cycle.
    tima_read <= visible_tima_after_tick(div_counter, G_DIV_COUNTER_STEP,
                                         tima_reg, tma_reg, tac_reg,
                                         overflow_pending)
                 when G_TIMA_READ_AFTER_TICK else tima_reg;
    tma_read <= tma_reg;
    tac_read <= "11111" & tac_reg;
    timer_interrupt_set <= timer_interrupt_set_reg;

end architecture rtl;
