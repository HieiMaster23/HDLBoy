# =============================================================================
# SDRAM CPU ROM Timing Constraints
# Target: sdram_cpu_rom_top on OMDAZZ RZ-EasyFPGA A2.2
# =============================================================================
# First load-then-execute bring-up constraint set. SDRAM board-level I/O timing
# remains relaxed until the cartridge path is proven functionally.
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

set tck_clock [get_clocks -nowarn {altera_reserved_tck}]
if {[get_collection_size $tck_clock] > 0} {
    set_false_path -from $tck_clock
    set_false_path -to $tck_clock
}

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

set jtag_input_ports [get_ports -nowarn {altera_reserved_tdi altera_reserved_tms}]
if {[get_collection_size $jtag_input_ports] > 0} {
    set_false_path -from $jtag_input_ports
}

set jtag_output_ports [get_ports -nowarn {altera_reserved_tdo}]
if {[get_collection_size $jtag_output_ports] > 0} {
    set_false_path -to $jtag_output_ports
}
