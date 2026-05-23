# =============================================================================
# SDRAM Bring-Up Timing Constraints
# Target: sdram_test_top on OMDAZZ RZ-EasyFPGA A2.2
# =============================================================================
# This file is intentionally limited to the first functional SDRAM bring-up.
# Board-level SDRAM setup/hold constraints must be revisited before integrating
# the SDRAM path with the Game Boy cartridge bus.
# =============================================================================

set sdram_output_ports [get_ports -nowarn {
    sdram_clk
    sdram_cke
    sdram_cs_n
    sdram_ras_n
    sdram_cas_n
    sdram_we_n
    sdram_dqm[*]
    sdram_ba[*]
    sdram_addr[*]
}]

if {[get_collection_size $sdram_output_ports] > 0} {
    set_false_path -to $sdram_output_ports
}

set sdram_data_ports [get_ports -nowarn {sdram_dq[*]}]
if {[get_collection_size $sdram_data_ports] > 0} {
    set_false_path -to $sdram_data_ports
    set_false_path -from $sdram_data_ports
}
