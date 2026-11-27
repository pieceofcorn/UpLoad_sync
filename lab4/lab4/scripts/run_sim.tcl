# Optional batch usage: vivado -mode batch -source scripts/run_sim.tcl -tclargs core
set lab4_test core
if {[llength $argv] > 1} {error "Use one test name: core or board"}
if {[llength $argv] == 1} {set lab4_test [lindex $argv 0]}
if {$lab4_test ni {core board}} {error "Use core or board"}
source [file join [file dirname [info script]] create_project.tcl]
set lab4_top tb_alu_core
set lab4_status_name lab4_sim_status.txt
set lab4_min_checks 18160
if {$lab4_test eq "board"} {
    set lab4_top tb_lab4_top
    set lab4_status_name lab4_board_status.txt
    set lab4_min_checks 166
}
set_property top $lab4_top [get_filesets sim_1]
set lab4_status_path [file join $lab4_project_dir lab4.sim sim_1 behav xsim $lab4_status_name]
if {[file exists $lab4_status_path]} {file delete -- $lab4_status_path}
set lab4_failed [catch {
    launch_simulation -simset sim_1 -mode behavioral
    run all
} lab4_detail]
catch {close_sim}
if {![file exists $lab4_status_path]} {
    puts stderr "No completed result for this run: $lab4_status_path"
    puts stderr $lab4_detail
    exit 1
}
set lab4_handle [open $lab4_status_path r]
set lab4_status [string trim [read $lab4_handle]]
close $lab4_handle
puts "LAB4_SIM_STATUS=$lab4_status"
set lab4_pass [regexp {^PASS checks=([0-9]+) errors=0$} $lab4_status unused lab4_checks]
if {$lab4_failed || !$lab4_pass} {puts stderr $lab4_detail; exit 1}
if {$lab4_checks < $lab4_min_checks} {puts stderr "Required checks are missing"; exit 1}
exit 0
