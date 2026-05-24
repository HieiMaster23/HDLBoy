# =============================================================================
# SDRAM Virtual JTAG Loader Timing Constraints
# Target: sdram_jtag_loader_top on OMDAZZ RZ-EasyFPGA A2.2
# =============================================================================
# This file is intentionally limited to the first functional ROM-loading
# bring-up. Board-level SDRAM setup/hold constraints must be revisited before
# integrating the SDRAM path with the Game Boy cartridge bus.
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

set clk50_clock [get_clocks -nowarn {clk_50mhz}]
set tck_clock [get_clocks -nowarn {altera_reserved_tck}]

if {[get_collection_size $clk50_clock] > 0 && [get_collection_size $tck_clock] > 0} {
    set_clock_groups -asynchronous -group $clk50_clock -group $tck_clock
}

set reset_ports [get_ports -nowarn {reset_n}]
if {[get_collection_size $reset_ports] > 0} {
    set_false_path -from $reset_ports
}

set jtag_input_ports [get_ports -nowarn {altera_reserved_tdi altera_reserved_tms}]
if {[get_collection_size $jtag_input_ports] > 0} {
    set_false_path -from $jtag_input_ports
}

set jtag_output_ports [get_ports -nowarn {altera_reserved_tdo}]
if {[get_collection_size $jtag_output_ports] > 0} {
    set_false_path -to $jtag_output_ports
}
