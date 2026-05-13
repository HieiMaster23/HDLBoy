# RZ-EasyFPGA A2.2 Pinout Notes

The active constraints in `constraints/pin_assignments.qsf` are based on public
RZ-EasyFPGA A2.2 references and should still be checked against the exact board
schematic before hardware testing.

## Current Active Pins

| Signal | FPGA Pin | Notes |
| --- | ---: | --- |
| `clk_50mhz` | 23 | 50 MHz board oscillator |
| `reset_n` | 25 | Active-low reset |
| `led[0]` | 87 | Active-low LED |
| `led[1]` | 86 | Active-low LED |
| `led[2]` | 85 | Active-low LED |
| `led[3]` | 84 | Active-low LED |
| `seg[0]` | 128 | Seven-segment segment A, active-low |
| `seg[1]` | 121 | Seven-segment segment B, active-low |
| `seg[2]` | 125 | Seven-segment segment C, active-low |
| `seg[3]` | 129 | Seven-segment segment D, active-low |
| `seg[4]` | 132 | Seven-segment segment E, active-low |
| `seg[5]` | 126 | Seven-segment segment F, active-low |
| `seg[6]` | 124 | Seven-segment segment G, active-low |
| `seg[7]` | 127 | Seven-segment decimal point, active-low |
| `digit_n[0]` | 137 | Leftmost logical digit enable, active-low |
| `digit_n[1]` | 136 | Digit enable, active-low |
| `digit_n[2]` | 135 | Digit enable, active-low |
| `digit_n[3]` | 133 | Rightmost logical digit enable, active-low |
| `vga_hsync` | 101 | VGA horizontal sync |
| `vga_vsync` | 103 | VGA vertical sync |
| `vga_b` | 104 | Scalar blue channel |
| `vga_g` | 105 | Scalar green channel |
| `vga_r` | 106 | Scalar red channel |

## References Used

- `dualvim/KitEasyFPGA_EP4CE6`, `Docs_Kit/EsquemaEletrico_e_Pinagem/Pinos_RZEasyFPGA.txt`
- `inaciose/RZ-easyFPGA-A2.2`, `rz_easyfpga_2_2.qsf`
- `fsmiamoto/EasyFPGA-VGA`, `EasyFPGA-VGA.qsf`

All three public references list VGA as scalar `R/G/B` pins, not 3-bit color
buses. For that reason the hardware tops expose scalar VGA pins and keep wider
RGB only inside the video pipeline.
