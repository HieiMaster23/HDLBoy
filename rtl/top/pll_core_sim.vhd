-- =============================================================================
-- Module:      pll_core (simulation stub)
-- Description: Simulation-only PLL replacement — same interface as ALTPLL-generated pll_core
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-03-25
-- Target:      Simulation only (ModelSim without altera_mf library)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Provides the same entity interface as the Quartus ALTPLL-generated pll_core.vhd
-- but simply passes the input clock through as c0 (VGA) and generates a divided
-- clock for c1 (CPU). Use this for simulation when altera_mf is not available.
--
-- For synthesis, the real pll_core.vhd (ALTPLL megafunction) is used instead.
-- =============================================================================
-- Revision History:
-- 2026-03-25 - Initial creation for M2 simulation
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity pll_core is
    port (
        areset : in  std_logic := '0';
        inclk0 : in  std_logic := '0';
        c0     : out std_logic;
        c1     : out std_logic;
        locked : out std_logic
    );
end entity pll_core;

architecture sim of pll_core is
begin

    -- Pass input clock directly as VGA clock (testbench provides correct frequency)
    c0     <= inclk0;
    -- CPU clock not used in M1/M2 tests
    c1     <= '0';
    -- Locked after a short delay (simulate PLL lock time)
    locked <= '0' when areset = '1' else '1';

end architecture sim;
