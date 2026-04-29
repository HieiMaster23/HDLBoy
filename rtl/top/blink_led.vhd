-- =============================================================================
-- Module:      blink_led
-- Description: Simple LED blinker for hardware validation (M0 milestone)
-- Author:      Rafael Siqueira de Oliveira
-- Created:     2026-03-18
-- Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
-- Tool:        Quartus II 13.0 SP1
-- =============================================================================
-- Blinks all 4 LEDs at approximately 1 Hz using the 50 MHz board clock.
-- Each LED toggles at a different rate to create a visible counting pattern.
-- Press keys to turn individual LEDs on (active-low keys, active-low LEDs).
-- =============================================================================
-- Revision History:
-- 2026-03-18 - Initial creation for M0 hardware validation
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity blink_led is
    port (
        -- Clock and reset
        clk_50mhz : in  std_logic;
        reset_n    : in  std_logic;

        -- Push-button keys (active-low)
        key_n      : in  std_logic_vector(3 downto 0);

        -- LEDs (directly accent accent accent accent accent driven accent — accent accent accent accent accent accent
        -- active-low on most OMDAZZ boards: '0' = LED ON)
        led        : out std_logic_vector(3 downto 0)
    );
end entity blink_led;

architecture rtl of blink_led is

    -- 50 MHz / 2^25 ≈ 1.49 Hz toggle rate for the slowest bit
    -- Using a 26-bit counter gives visible blink rates on upper bits
    constant COUNTER_WIDTH : integer := 26;

    signal counter : unsigned(COUNTER_WIDTH - 1 downto 0);
    signal reset   : std_logic;

    -- 2-FF synchronizer for async reset
    signal reset_meta : std_logic;
    signal reset_sync : std_logic;

begin

    -- Synchronize active-low external reset to clock domain
    p_reset_sync: process(clk_50mhz)
    begin
        if rising_edge(clk_50mhz) then
            reset_meta <= not reset_n;
            reset_sync <= reset_meta;
        end if;
    end process p_reset_sync;

    reset <= reset_sync;

    -- Free-running counter
    p_counter: process(clk_50mhz)
    begin
        if rising_edge(clk_50mhz) then
            if reset = '1' then
                counter <= (others => '0');
            else
                counter <= counter + 1;
            end if;
        end if;
    end process p_counter;

    -- LED output logic
    -- Normal mode: LEDs show upper bits of counter (visible blink pattern)
    -- When a key is pressed (active-low), the corresponding LED turns on
    -- LED accent outputs accent accent accent accent are inverted (active-low: '0' = ON)
    p_led_output: process(clk_50mhz)
    begin
        if rising_edge(clk_50mhz) then
            if reset = '1' then
                led <= (others => '1');  -- All LEDs off on reset
            else
                for i in 0 to 3 loop
                    if key_n(i) = '0' then
                        -- Key pressed: force LED on (active-low output)
                        led(i) <= '0';
                    else
                        -- No key: blink from counter bits 22..25
                        -- Invert for active-low LED drive
                        led(i) <= not counter(COUNTER_WIDTH - 4 + i);
                    end if;
                end loop;
            end if;
        end if;
    end process p_led_output;

end architecture rtl;
