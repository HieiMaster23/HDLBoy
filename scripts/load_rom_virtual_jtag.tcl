# =============================================================================
# Script:      load_rom_virtual_jtag.tcl
# Description: Load a Game Boy ROM into SDRAM through the Virtual JTAG loader
# Author:      Rafael Siqueira de Oliveira
# Created:     2026-05-25
# Target:      Altera Cyclone IV EP4CE6 E22C8N (OMDAZZ RZ-EasyFPGA A2.2)
# Tool:        Quartus II 13.0 SP1
# =============================================================================
#
# Usage:
#   quartus_stp -t scripts/load_rom_virtual_jtag.tcl path/to/rom.gb
#
# Optional:
#   quartus_stp -t scripts/load_rom_virtual_jtag.tcl --dry-run path/to/rom.gb
#   quartus_stp -t scripts/load_rom_virtual_jtag.tcl --max-bytes 32768 rom.gb
#   quartus_stp -t scripts/load_rom_virtual_jtag.tcl --hardware-name "<name>" rom.gb
#   quartus_stp -t scripts/load_rom_virtual_jtag.tcl --device-name "<name>" rom.gb
#
# Virtual JTAG protocol:
#   IR 1: DATA, shifts one ROM byte
#   IR 2: CONTROL, bit 0=start, bit 1=finish, bit 2=clear overflow
#   IR 3: STATUS
#
# STATUS bits:
#   bit 0: stream_ready
#   bit 1: loader_busy
#   bit 2: loader_done
#   bit 3: loader_error
#   bit 4: sdram_init_done
#   bit 5: byte pending in JTAG domain
#   bit 6: protocol overflow
#   bit 7: fixed signature bit
# =============================================================================

set IR_DATA    1
set IR_CONTROL 2
set IR_STATUS  3

set STATUS_READY    0x01
set STATUS_BUSY     0x02
set STATUS_DONE     0x04
set STATUS_ERROR    0x08
set STATUS_INIT     0x10
set STATUS_PENDING  0x20
set STATUS_OVERFLOW 0x40
set STATUS_SIGNATURE 0x80

proc script_args {} {
    if {[info exists ::quartus(args)]} {
        return $::quartus(args)
    }
    return $::argv
}

proc usage {} {
    puts "Usage: quartus_stp -t scripts/load_rom_virtual_jtag.tcl ?options? rom.gb"
    puts ""
    puts "Options:"
    puts "  --dry-run                 Parse the ROM and print the planned transfer only"
    puts "  --hardware-name <name>    Select a JTAG hardware name"
    puts "  --device-name <name>      Select a JTAG device name"
    puts "  --instance-index <n>      Virtual JTAG instance index, default 0"
    puts "  --max-bytes <n>           Limit transfer size for bring-up"
    puts "  --poll-limit <n>          Poll iterations before timeout, default 100000"
    puts "  --progress-step <n>       Print progress every n bytes, default 1024"
    puts "  --quiet                   Reduce progress output"
    puts "  --help                    Show this message"
}

proc parse_args {args_in} {
    array set cfg {
        dry_run 0
        hardware_name ""
        device_name ""
        instance_index 0
        max_bytes -1
        poll_limit 100000
        progress_step 1024
        quiet 0
        rom_path ""
    }

    set i 0
    while {$i < [llength $args_in]} {
        set arg [lindex $args_in $i]
        if {$arg eq "--dry-run"} {
            set cfg(dry_run) 1
        } elseif {$arg eq "--quiet"} {
            set cfg(quiet) 1
        } elseif {$arg eq "--help" || $arg eq "-h"} {
            usage
            exit 0
        } elseif {$arg eq "--hardware-name"} {
            incr i
            if {$i >= [llength $args_in]} { error "Missing value after --hardware-name" }
            set cfg(hardware_name) [lindex $args_in $i]
        } elseif {$arg eq "--device-name"} {
            incr i
            if {$i >= [llength $args_in]} { error "Missing value after --device-name" }
            set cfg(device_name) [lindex $args_in $i]
        } elseif {$arg eq "--instance-index"} {
            incr i
            if {$i >= [llength $args_in]} { error "Missing value after --instance-index" }
            set cfg(instance_index) [parse_nonnegative_int [lindex $args_in $i] "--instance-index"]
        } elseif {$arg eq "--max-bytes"} {
            incr i
            if {$i >= [llength $args_in]} { error "Missing value after --max-bytes" }
            set cfg(max_bytes) [parse_positive_int [lindex $args_in $i] "--max-bytes"]
        } elseif {$arg eq "--poll-limit"} {
            incr i
            if {$i >= [llength $args_in]} { error "Missing value after --poll-limit" }
            set cfg(poll_limit) [parse_positive_int [lindex $args_in $i] "--poll-limit"]
        } elseif {$arg eq "--progress-step"} {
            incr i
            if {$i >= [llength $args_in]} { error "Missing value after --progress-step" }
            set cfg(progress_step) [parse_positive_int [lindex $args_in $i] "--progress-step"]
        } elseif {[string match "--*" $arg]} {
            error "Unknown option: $arg"
        } elseif {$cfg(rom_path) eq ""} {
            set cfg(rom_path) $arg
        } else {
            error "Unexpected extra argument: $arg"
        }
        incr i
    }

    if {$cfg(rom_path) eq ""} {
        usage
        error "Missing ROM path"
    }

    return [array get cfg]
}

proc parse_positive_int {value name} {
    if {![string is integer -strict $value] || $value <= 0} {
        error "$name must be a positive integer"
    }
    return $value
}

proc parse_nonnegative_int {value name} {
    if {![string is integer -strict $value] || $value < 0} {
        error "$name must be a non-negative integer"
    }
    return $value
}

proc read_rom_bytes {rom_path max_bytes} {
    if {![file exists $rom_path]} {
        error "ROM file not found: $rom_path"
    }

    set fh [open $rom_path rb]
    fconfigure $fh -translation binary -encoding binary
    set data [read $fh]
    close $fh

    if {$max_bytes > 0 && [string length $data] > $max_bytes} {
        set data [string range $data 0 [expr {$max_bytes - 1}]]
    }

    binary scan $data c* signed_values
    set bytes {}
    foreach value $signed_values {
        lappend bytes [expr {$value & 0xff}]
    }
    return $bytes
}

proc checksum16 {bytes} {
    set sum 0
    foreach value $bytes {
        set sum [expr {($sum + $value) & 0xffff}]
    }
    return $sum
}

proc status_to_string {status} {
    set fields {}
    if {$status & $::STATUS_READY}    { lappend fields "ready" }
    if {$status & $::STATUS_BUSY}     { lappend fields "busy" }
    if {$status & $::STATUS_DONE}     { lappend fields "done" }
    if {$status & $::STATUS_ERROR}    { lappend fields "error" }
    if {$status & $::STATUS_INIT}     { lappend fields "sdram_init" }
    if {$status & $::STATUS_PENDING}  { lappend fields "pending" }
    if {$status & $::STATUS_OVERFLOW} { lappend fields "overflow" }
    if {$status & $::STATUS_SIGNATURE} { lappend fields "signature" }
    if {[llength $fields] == 0} {
        return "none"
    }
    return [join $fields ","]
}

proc require_quartus_jtag {} {
    foreach cmd {get_hardware_names get_device_names open_device close_device device_lock device_unlock device_virtual_ir_shift device_virtual_dr_shift} {
        if {[llength [info commands $cmd]] == 0} {
            error "Quartus JTAG command '$cmd' is unavailable. Run this script with quartus_stp, or use --dry-run."
        }
    }
}

proc open_jtag_target {cfg_name} {
    upvar 1 $cfg_name cfg

    set hardware_name $cfg(hardware_name)
    if {$hardware_name eq ""} {
        set hardware_names [get_hardware_names]
        if {[llength $hardware_names] == 0} {
            error "No JTAG hardware found"
        }
        set hardware_name [lindex $hardware_names 0]
    }

    set device_name $cfg(device_name)
    if {$device_name eq ""} {
        set device_names [get_device_names -hardware_name $hardware_name]
        if {[llength $device_names] == 0} {
            error "No JTAG device found on hardware '$hardware_name'"
        }
        set device_name [lindex $device_names 0]
    }

    puts "Opening JTAG hardware: $hardware_name"
    puts "Opening JTAG device:   $device_name"
    open_device -hardware_name $hardware_name -device_name $device_name
}

proc select_ir {cfg_name ir_value} {
    upvar 1 $cfg_name cfg
    device_virtual_ir_shift \
        -instance_index $cfg(instance_index) \
        -ir_value $ir_value \
        -no_captured_ir_value
}

proc read_status {cfg_name} {
    upvar 1 $cfg_name cfg
    select_ir cfg $::IR_STATUS
    set status_hex [device_virtual_dr_shift \
        -instance_index $cfg(instance_index) \
        -length 8 \
        -value_in_hex]
    scan $status_hex "%x" status
    return [expr {$status & 0xff}]
}

proc send_control {cfg_name control_value} {
    upvar 1 $cfg_name cfg
    select_ir cfg $::IR_CONTROL
    device_virtual_dr_shift \
        -instance_index $cfg(instance_index) \
        -length 8 \
        -dr_value [format "%02X" $control_value] \
        -value_in_hex \
        -no_captured_dr_value
}

proc send_data_byte {cfg_name byte_value} {
    upvar 1 $cfg_name cfg
    select_ir cfg $::IR_DATA
    device_virtual_dr_shift \
        -instance_index $cfg(instance_index) \
        -length 8 \
        -dr_value [format "%02X" $byte_value] \
        -value_in_hex \
        -no_captured_dr_value
}

proc poll_status {cfg_name required_clear required_set message} {
    upvar 1 $cfg_name cfg
    for {set attempt 0} {$attempt < $cfg(poll_limit)} {incr attempt} {
        set status [read_status cfg]
        if {($status & $::STATUS_SIGNATURE) == 0} {
            error "Invalid status signature while waiting for $message: 0x[format %02X $status]"
        }
        if {$status & $::STATUS_ERROR} {
            error "Loader error while waiting for $message: 0x[format %02X $status] ([status_to_string $status])"
        }
        if {$status & $::STATUS_OVERFLOW} {
            error "Virtual JTAG protocol overflow while waiting for $message: 0x[format %02X $status] ([status_to_string $status])"
        }
        if {(($status & $required_clear) == 0) && (($status & $required_set) == $required_set)} {
            return $status
        }
    }

    error "Timeout while waiting for $message"
}

proc transfer_rom {cfg_name bytes} {
    upvar 1 $cfg_name cfg

    puts "Waiting for SDRAM initialization..."
    set status [poll_status cfg 0 $::STATUS_INIT "SDRAM init"]
    puts "Initial status: 0x[format %02X $status] ([status_to_string $status])"

    send_control cfg 4
    send_control cfg 1

    set total [llength $bytes]
    set index 0
    foreach byte_value $bytes {
        poll_status cfg $::STATUS_PENDING [expr {$::STATUS_READY | $::STATUS_INIT}] "byte-ready"
        send_data_byte cfg $byte_value
        incr index

        if {!$cfg(quiet) && (($index % $cfg(progress_step)) == 0 || $index == $total)} {
            puts "Transferred $index / $total bytes"
        }
    }

    poll_status cfg $::STATUS_PENDING [expr {$::STATUS_READY | $::STATUS_INIT}] "finish-ready"
    send_control cfg 2
    set status [poll_status cfg $::STATUS_BUSY [expr {$::STATUS_DONE | $::STATUS_INIT}] "loader done"]
    puts "Final status: 0x[format %02X $status] ([status_to_string $status])"
}

proc main {} {
    array set cfg [parse_args [script_args]]
    set bytes [read_rom_bytes $cfg(rom_path) $cfg(max_bytes)]
    set byte_count [llength $bytes]
    set word_count [expr {($byte_count + 1) / 2}]
    set sum [checksum16 $bytes]

    puts "ROM:        $cfg(rom_path)"
    puts "Bytes:      $byte_count"
    puts "SDRAM words: $word_count"
    puts "Checksum16: 0x[format %04X $sum]"

    if {$cfg(dry_run)} {
        puts "Dry-run complete. No JTAG access was attempted."
        return
    }

    require_quartus_jtag
    open_jtag_target cfg

    set locked 0
    set rc [catch {
        device_lock -timeout 10000
        set locked 1
        transfer_rom cfg $bytes
    } result]

    if {$locked} {
        catch {device_unlock}
    }
    catch {close_device}

    if {$rc != 0} {
        error $result
    }

    puts "ROM load completed."
}

main
