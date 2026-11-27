# Full FPGA build: synthesis, implementation, timing/DRC reports, and bitstream.
# Run from any directory:
# vivado -mode batch -source <lab4>/scripts/run_build.tcl
#
# Optional argument: number of parallel jobs (default 4).
# This script does not connect to or program a physical FPGA.

set lab4_jobs 4
if {[llength $argv] > 1} {
    puts stderr "Usage: run_build.tcl ?jobs?"
    exit 1
}
if {[llength $argv] == 1} {
    set lab4_jobs [lindex $argv 0]
}
if {![string is integer -strict $lab4_jobs] || $lab4_jobs < 1} {
    puts stderr "jobs must be a positive integer"
    exit 1
}

set lab4_script_dir [file dirname [file normalize [info script]]]
set lab4_root [file normalize [file join $lab4_script_dir ..]]
source [file join $lab4_root scripts create_project.tcl]

set lab4_expected_part xc7a100tfgg484-1
set lab4_design_top lab4_top
if {[get_property PART [current_project]] ne $lab4_expected_part} {
    puts stderr "Unexpected FPGA part: [get_property PART [current_project]]"
    exit 1
}
set_property top $lab4_design_top [get_filesets sources_1]
update_compile_order -fileset sources_1

set lab4_report_dir [file join $lab4_project_dir reports]
file mkdir $lab4_report_dir

puts "\n========== LAB4 FPGA BUILD =========="
puts "PROJECT=[get_property NAME [current_project]]"
puts "PART=[get_property PART [current_project]]"
puts "TOP=$lab4_design_top"
puts "JOBS=$lab4_jobs"
puts "REPORT_DIR=$lab4_report_dir"

# Reset old runs so the reports and bitstream belong to this invocation.
if {[catch {
    reset_run impl_1
    reset_run synth_1
} lab4_reset_error]} {
    puts stderr "Could not reset Vivado runs: $lab4_reset_error"
    exit 1
}

# Stage 1: synthesis.
puts "\n========== SYNTHESIS =========="
if {[catch {
    launch_runs synth_1 -jobs $lab4_jobs
    wait_on_run synth_1
} lab4_synth_error]} {
    puts stderr "Synthesis launch/wait failed: $lab4_synth_error"
    exit 1
}
set lab4_synth_run [get_runs synth_1]
set lab4_synth_status [get_property STATUS $lab4_synth_run]
set lab4_synth_progress [get_property PROGRESS $lab4_synth_run]
puts "SYNTH_STATUS=$lab4_synth_status"
puts "SYNTH_PROGRESS=$lab4_synth_progress"
if {[string first "Complete" $lab4_synth_status] < 0} {
    puts stderr "Synthesis did not complete successfully."
    exit 1
}

if {[catch {
    open_run synth_1
    report_utilization -file [file join $lab4_report_dir synthesis_utilization.rpt]
    report_timing_summary -file [file join $lab4_report_dir synthesis_timing_summary.rpt]
    close_design
} lab4_synth_report_error]} {
    puts stderr "Could not generate synthesis reports: $lab4_synth_report_error"
    exit 1
}

# Stage 2: implementation through bitstream generation.
puts "\n========== IMPLEMENTATION + BITSTREAM =========="
if {[catch {
    launch_runs impl_1 -to_step write_bitstream -jobs $lab4_jobs
    wait_on_run impl_1
} lab4_impl_error]} {
    puts stderr "Implementation launch/wait failed: $lab4_impl_error"
    exit 1
}
set lab4_impl_run [get_runs impl_1]
set lab4_impl_status [get_property STATUS $lab4_impl_run]
set lab4_impl_progress [get_property PROGRESS $lab4_impl_run]
puts "IMPL_STATUS=$lab4_impl_status"
puts "IMPL_PROGRESS=$lab4_impl_progress"
if {[string first "Complete" $lab4_impl_status] < 0} {
    puts stderr "Implementation/bitstream generation did not complete successfully."
    exit 1
}

# Stage 3: reports from the routed implementation.
if {[catch {
    open_run impl_1
    report_utilization -file [file join $lab4_report_dir implementation_utilization.rpt]
    report_timing_summary -file [file join $lab4_report_dir implementation_timing_summary.rpt]
    report_drc -file [file join $lab4_report_dir implementation_drc.rpt]
} lab4_report_error]} {
    puts stderr "Could not generate implementation reports: $lab4_report_error"
    exit 1
}

set lab4_setup_paths [get_timing_paths -delay_type max -max_paths 1]
if {[llength $lab4_setup_paths] > 0} {
    set lab4_wns [get_property SLACK [lindex $lab4_setup_paths 0]]
    puts "WORST_SETUP_SLACK_NS=$lab4_wns"
    if {[string is double -strict $lab4_wns] && $lab4_wns < 0.0} {
        puts "TIMING_WARNING=Negative setup slack; inspect implementation_timing_summary.rpt"
    }
} else {
    puts "TIMING_WARNING=No maximum-delay timing path was returned."
}

set lab4_hold_paths [get_timing_paths -delay_type min -max_paths 1]
if {[llength $lab4_hold_paths] > 0} {
    set lab4_whs [get_property SLACK [lindex $lab4_hold_paths 0]]
    puts "WORST_HOLD_SLACK_NS=$lab4_whs"
    if {[string is double -strict $lab4_whs] && $lab4_whs < 0.0} {
        puts "TIMING_WARNING=Negative hold slack; inspect implementation_timing_summary.rpt"
    }
}

close_design

set lab4_impl_dir [file normalize [get_property DIRECTORY $lab4_impl_run]]
set lab4_bitfile [file join $lab4_impl_dir lab4_top.bit]
if {![file isfile $lab4_bitfile]} {
    puts stderr "Expected bitstream was not found: $lab4_bitfile"
    exit 1
}

puts "\n========== BUILD COMPLETE =========="
puts "BITSTREAM=$lab4_bitfile"
puts "SYNTH_REPORT=[file join $lab4_report_dir synthesis_utilization.rpt]"
puts "IMPL_REPORT=[file join $lab4_report_dir implementation_utilization.rpt]"
puts "TIMING_REPORT=[file join $lab4_report_dir implementation_timing_summary.rpt]"
puts "DRC_REPORT=[file join $lab4_report_dir implementation_drc.rpt]"
puts "NOTE=This script does not program the connected FPGA."
close_project
exit 0
