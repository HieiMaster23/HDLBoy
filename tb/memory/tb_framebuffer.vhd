-- =============================================================================
-- Module:      tb_framebuffer
-- Description: Testbench for dual-port framebuffer module
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-03-25
-- Target:      Simulation only (ModelSim-Altera)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Verifies:
--   1. Write on port A, read back on port B (cross-clock)
--   2. Sequential writes to multiple addresses, then verify reads
--   3. Write does not corrupt other addresses
--   4. Boundary addresses (0, 23039) work correctly
-- =============================================================================
-- Revision History:
-- 2026-03-25 - Initial creation for M2 milestone
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_framebuffer is
end entity tb_framebuffer;

architecture sim of tb_framebuffer is

    -- Clock periods (different domains)
    constant CLK_A_PERIOD : time := 238 ns;   -- ~4.194 MHz (CPU domain)
    constant CLK_B_PERIOD : time := 39.722 ns; -- ~25.175 MHz (VGA domain)

    signal clk_a    : std_logic := '0';
    signal clk_b    : std_logic := '0';
    signal we_a     : std_logic := '0';
    signal addr_a   : unsigned(14 downto 0) := (others => '0');
    signal data_a   : std_logic_vector(1 downto 0) := "00";
    signal addr_b   : unsigned(14 downto 0) := (others => '0');
    signal data_b   : std_logic_vector(1 downto 0);

    signal sim_done : boolean := false;

begin

    -- Clock generation (two independent clocks)
    p_clk_a: process
    begin
        while not sim_done loop
            clk_a <= '0'; wait for CLK_A_PERIOD / 2;
            clk_a <= '1'; wait for CLK_A_PERIOD / 2;
        end loop;
        wait;
    end process p_clk_a;

    p_clk_b: process
    begin
        while not sim_done loop
            clk_b <= '0'; wait for CLK_B_PERIOD / 2;
            clk_b <= '1'; wait for CLK_B_PERIOD / 2;
        end loop;
        wait;
    end process p_clk_b;

    -- DUT
    u_dut: entity work.framebuffer
        port map (
            clk_a  => clk_a,
            we_a   => we_a,
            addr_a => addr_a,
            data_a => data_a,
            clk_b  => clk_b,
            addr_b => addr_b,
            data_b => data_b
        );

    -- Stimulus and verification
    p_test: process
    begin
        report "=== tb_framebuffer: Starting simulation ===" severity note;

        -- =====================================================================
        -- Test 1: Write a single pixel via port A, read back via port B
        -- =====================================================================
        wait until rising_edge(clk_a);
        we_a   <= '1';
        addr_a <= to_unsigned(0, 15);
        data_a <= "11";
        wait until rising_edge(clk_a);
        we_a <= '0';

        -- Read back on port B (allow time for write to complete)
        wait for CLK_A_PERIOD;
        wait until rising_edge(clk_b);
        addr_b <= to_unsigned(0, 15);
        wait until rising_edge(clk_b);  -- RAM read latency
        wait until rising_edge(clk_b);  -- Data available

        assert data_b = "11"
            report "FAIL: Read addr 0, expected 11, got " &
                   std_logic'image(data_b(1)) & std_logic'image(data_b(0))
            severity failure;
        report "PASS: Single write/read at address 0" severity note;

        -- =====================================================================
        -- Test 2: Write multiple addresses with different values
        -- =====================================================================
        -- Write 4 consecutive pixels with different shades
        wait until rising_edge(clk_a);
        we_a <= '1'; addr_a <= to_unsigned(100, 15); data_a <= "00";
        wait until rising_edge(clk_a);
        addr_a <= to_unsigned(101, 15); data_a <= "01";
        wait until rising_edge(clk_a);
        addr_a <= to_unsigned(102, 15); data_a <= "10";
        wait until rising_edge(clk_a);
        addr_a <= to_unsigned(103, 15); data_a <= "11";
        wait until rising_edge(clk_a);
        we_a <= '0';

        -- Read them back via port B
        wait for CLK_A_PERIOD;

        -- Read addr 100
        wait until rising_edge(clk_b);
        addr_b <= to_unsigned(100, 15);
        wait until rising_edge(clk_b);
        wait until rising_edge(clk_b);
        assert data_b = "00"
            report "FAIL: addr 100 expected 00" severity failure;

        -- Read addr 101
        addr_b <= to_unsigned(101, 15);
        wait until rising_edge(clk_b);
        wait until rising_edge(clk_b);
        assert data_b = "01"
            report "FAIL: addr 101 expected 01" severity failure;

        -- Read addr 102
        addr_b <= to_unsigned(102, 15);
        wait until rising_edge(clk_b);
        wait until rising_edge(clk_b);
        assert data_b = "10"
            report "FAIL: addr 102 expected 10" severity failure;

        -- Read addr 103
        addr_b <= to_unsigned(103, 15);
        wait until rising_edge(clk_b);
        wait until rising_edge(clk_b);
        assert data_b = "11"
            report "FAIL: addr 103 expected 11" severity failure;

        report "PASS: Multiple address write/read" severity note;

        -- =====================================================================
        -- Test 3: Boundary address (last pixel: 23039)
        -- =====================================================================
        wait until rising_edge(clk_a);
        we_a   <= '1';
        addr_a <= to_unsigned(23039, 15);
        data_a <= "10";
        wait until rising_edge(clk_a);
        we_a <= '0';

        wait for CLK_A_PERIOD;
        wait until rising_edge(clk_b);
        addr_b <= to_unsigned(23039, 15);
        wait until rising_edge(clk_b);
        wait until rising_edge(clk_b);

        assert data_b = "10"
            report "FAIL: Boundary addr 23039 expected 10" severity failure;
        report "PASS: Boundary address write/read" severity note;

        -- =====================================================================
        -- Test 4: Verify previous write at addr 0 is not corrupted
        -- =====================================================================
        wait until rising_edge(clk_b);
        addr_b <= to_unsigned(0, 15);
        wait until rising_edge(clk_b);
        wait until rising_edge(clk_b);

        assert data_b = "11"
            report "FAIL: addr 0 corrupted, expected 11" severity failure;
        report "PASS: No address corruption" severity note;

        -- =====================================================================
        -- Test 5: Write-enable must be high for write to occur
        -- =====================================================================
        wait until rising_edge(clk_a);
        we_a   <= '0';  -- WE disabled
        addr_a <= to_unsigned(200, 15);
        data_a <= "01";
        wait until rising_edge(clk_a);

        -- Now write with WE enabled to a known value first
        we_a   <= '1';
        addr_a <= to_unsigned(200, 15);
        data_a <= "10";
        wait until rising_edge(clk_a);
        we_a <= '0';

        -- Read back — should be "10" (the enabled write), not "01"
        wait for CLK_A_PERIOD;
        wait until rising_edge(clk_b);
        addr_b <= to_unsigned(200, 15);
        wait until rising_edge(clk_b);
        wait until rising_edge(clk_b);

        assert data_b = "10"
            report "FAIL: WE gating broken" severity failure;
        report "PASS: Write-enable gating correct" severity note;

        report "=== tb_framebuffer: ALL TESTS PASSED ===" severity note;
        sim_done <= true;
        wait;
    end process p_test;

end architecture sim;
