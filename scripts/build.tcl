# =============================================================================
# Quartus II Tcl Build Script - Game Boy FPGA Core
# Usage: quartus_sh -t build.tcl
# =============================================================================

package require ::quartus::project
package require ::quartus::flow

set project_name "gameboy_core"
set project_dir  [file join [file dirname [info script]] ".." "quartus"]
set revision_name $project_name

cd $project_dir

# Open project
if {[project_exists $project_name]} {
    project_open $project_name -revision $revision_name
} else {
    puts "ERROR: Project $project_name not found in $project_dir"
    exit 1
}

puts "=== Starting full compilation ==="

# Run full compilation flow (Analysis & Synthesis -> Fitter -> Assembler -> Timing)
if {[catch {execute_flow -compile} result]} {
    puts "ERROR: Compilation failed - $result"
    project_close
    exit 1
}

puts "=== Compilation successful ==="

# Print resource utilization summary
puts "\n=== Resource Utilization ==="
# The summary is in the .fit.summary file

project_close
