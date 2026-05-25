# =============================================================================
# Quartus II Tcl Build Script - SDRAM CPU ROM Top
# Usage: quartus_sh -t scripts/build_sdram_cpu_rom.tcl
# =============================================================================

package require ::quartus::project
package require ::quartus::flow

set project_name "gameboy_core"
set script_dir [file dirname [info script]]
set project_dir  [file join $script_dir ".." "quartus"]
set revision_name $project_name
set qsf_path [file join $project_dir "${revision_name}.qsf"]
set qsf_restore_path "${revision_name}.qsf"
set qsf_original ""

if {[file exists $qsf_path]} {
    set qsf_file [open $qsf_path r]
    set qsf_original [read $qsf_file]
    close $qsf_file
}

cd $project_dir

if {[project_exists $project_name]} {
    project_open $project_name -revision $revision_name
} else {
    puts "ERROR: Project $project_name not found in $project_dir"
    exit 1
}

set original_top [get_global_assignment -name TOP_LEVEL_ENTITY]

puts "=== Starting SDRAM CPU ROM top compilation ==="
puts "Original top-level entity: $original_top"

set_global_assignment -name TOP_LEVEL_ENTITY sdram_cpu_rom_top
set_global_assignment -name SDC_FILE ../constraints/sdram_cpu_rom_timing.sdc
source ../constraints/sdram_pin_assignments.qsf

if {[catch {execute_flow -compile} result]} {
    puts "ERROR: SDRAM CPU ROM compilation failed - $result"
    set_global_assignment -name TOP_LEVEL_ENTITY $original_top
    catch {remove_global_assignment -name SDC_FILE ../constraints/sdram_cpu_rom_timing.sdc}
    project_close
    if {$qsf_original ne ""} {
        set qsf_file [open $qsf_restore_path w]
        puts -nonewline $qsf_file $qsf_original
        close $qsf_file
    }
    exit 1
}

set_global_assignment -name TOP_LEVEL_ENTITY $original_top
catch {remove_global_assignment -name SDC_FILE ../constraints/sdram_cpu_rom_timing.sdc}
project_close

if {$qsf_original ne ""} {
    set qsf_file [open $qsf_restore_path w]
    puts -nonewline $qsf_file $qsf_original
    close $qsf_file
}

puts "=== SDRAM CPU ROM compilation successful ==="
puts "Project top-level entity restored to: $original_top"
