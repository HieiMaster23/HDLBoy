# =============================================================================
# Quartus II Tcl Build Script - SDRAM Bring-Up Top
# Usage: quartus_sh -t scripts/build_sdram_test.tcl
# =============================================================================

package require ::quartus::project
package require ::quartus::flow

set project_name "gameboy_core"
set project_dir  [file normalize [file join [file dirname [info script]] ".." "quartus"]]
set revision_name $project_name
set qsf_path [file join $project_dir "${revision_name}.qsf"]
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

puts "=== Starting SDRAM bring-up top compilation ==="
puts "Original top-level entity: $original_top"

set_global_assignment -name TOP_LEVEL_ENTITY sdram_test_top
set_global_assignment -name SDC_FILE ../constraints/sdram_test_timing.sdc
source ../constraints/sdram_pin_assignments.qsf

if {[catch {execute_flow -compile} result]} {
    puts "ERROR: SDRAM test compilation failed - $result"
    set_global_assignment -name TOP_LEVEL_ENTITY $original_top
    catch {remove_global_assignment -name SDC_FILE ../constraints/sdram_test_timing.sdc}
    project_close
    if {$qsf_original ne ""} {
        set qsf_file [open $qsf_path w]
        puts -nonewline $qsf_file $qsf_original
        close $qsf_file
    }
    exit 1
}

set_global_assignment -name TOP_LEVEL_ENTITY $original_top
catch {remove_global_assignment -name SDC_FILE ../constraints/sdram_test_timing.sdc}
project_close

if {$qsf_original ne ""} {
    set qsf_file [open $qsf_path w]
    puts -nonewline $qsf_file $qsf_original
    close $qsf_file
}

puts "=== SDRAM bring-up compilation successful ==="
puts "Project top-level entity restored to: $original_top"
