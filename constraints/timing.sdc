# =============================================================================
# Timing Constraints - Game Boy FPGA Core
# Target: Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
# Tool:   Quartus II 13.0 SP1
# =============================================================================

# -----------------------------------------------------------------------------
# Input Clock
# -----------------------------------------------------------------------------
create_clock -name clk_50mhz -period 20.000 [get_ports {clk_50mhz}]

# -----------------------------------------------------------------------------
# Derived Clocks
# -----------------------------------------------------------------------------
derive_pll_clocks
derive_clock_uncertainty

# -----------------------------------------------------------------------------
# Input/Output Delays (relaxed for M0/M2 board tests)
# -----------------------------------------------------------------------------
set reset_ports [get_ports -nowarn {reset_n}]
if {[get_collection_size $reset_ports] > 0} {
    set_false_path -from $reset_ports
}

set key_ports [get_ports -nowarn {key_n[*]}]
if {[get_collection_size $key_ports] > 0} {
    set_false_path -from $key_ports
}

set led_ports [get_ports -nowarn {led[*]}]
if {[get_collection_size $led_ports] > 0} {
    set_false_path -to $led_ports
}

set seven_seg_ports [get_ports -nowarn {seg[*] digit_n[*]}]
if {[get_collection_size $seven_seg_ports] > 0} {
    set_false_path -to $seven_seg_ports
}

set vga_ports [get_ports -nowarn {vga_*}]
if {[get_collection_size $vga_ports] > 0} {
    set_false_path -to $vga_ports
}
