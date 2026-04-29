# Design Decisions

## VHDL Standard

The project targets VHDL-1993 because Quartus II 13.0 SP1 and the bundled
ModelSim-Altera flow have limited VHDL-2008 support. Code should use only:

- `ieee.std_logic_1164`
- `ieee.numeric_std`

Non-standard Synopsys packages such as `std_logic_unsigned` and
`std_logic_arith` are intentionally avoided.

## Reset Strategy

External reset is active-low from the board. Top-level modules convert it to an
active-high internal reset and synchronize it in the relevant clock domain.
Subsystem RTL uses synchronous active-high reset where a reset is needed.

PLL asynchronous reset inputs are driven through named internal signals instead
of inline expressions in port maps. This keeps top-level files compatible with
strict VHDL-1993 tools.

## Framebuffer First

The project implements the framebuffer and VGA read path before the PPU. This
provides an early hardware-visible milestone and establishes the clock-domain
boundary between the future Game Boy pixel producer and VGA output.

The framebuffer stores native Game Boy pixels:

- 160x144 pixels.
- 2 bits per pixel.
- 46,080 total bits.
- Expected implementation: Cyclone IV M9K block RAM.

## VGA Pinout Caution

Public RZ-EasyFPGA A2.2 pin references commonly list VGA as scalar `VGA_R`,
`VGA_G`, and `VGA_B` pins rather than multi-bit DAC buses. The internal video
pipeline keeps 3-bit RGB channels so color depth can be adapted later, but the
board-level top should map only the physically available pins unless the exact
board schematic confirms a wider resistor DAC.

## Resource Discipline

The EP4CE6 has only 6,272 logic elements and 276,480 block RAM bits. Large
lookup tables and broad control abstractions should be introduced only when they
replace real complexity. Early milestones prioritize correctness, then resource
optimization is documented and applied after functional integration.
