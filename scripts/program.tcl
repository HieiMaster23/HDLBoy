# =============================================================================
# Quartus II Tcl Programming Script - Game Boy FPGA Core
# Usage: quartus_pgm -t program.tcl
# =============================================================================

set project_name "gameboy_core"
set project_dir  [file join [file dirname [info script]] ".." "quartus"]
set sof_file [file join $project_dir "output_files" "${project_name}.sof"]

if {![file exists $sof_file]} {
    puts "ERROR: SOF file not found at $sof_file"
    puts "Run build.tcl first to compile the project."
    exit 1
}

puts "=== Programming FPGA via JTAG ==="
puts "SOF file: $sof_file"

# Program via USB-Blaster
if {[catch {exec quartus_pgm -m jtag -o "p;$sof_file"} result]} {
    puts "ERROR: Programming failed - $result"
    exit 1
}

puts "=== Programming successful ==="
