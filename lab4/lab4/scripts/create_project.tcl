# Create or open the single lab4 project from the package location.
set lab4_root [file normalize [file join [file dirname [info script]] ..]]
set lab4_project_dir [file join $lab4_root build]
set lab4_project_name lab4
set lab4_xpr [file join $lab4_project_dir lab4.xpr]
set lab4_part xc7a100tfgg484-1
set lab4_design_files {}
foreach name {clu4 cla4 cla16 addsub32 alu_datapath alu_core} {
    lappend lab4_design_files [file join $lab4_root rtl core ${name}.v]
}
foreach name {button_clean hex8_scan lab4_top preset_vectors} {
    lappend lab4_design_files [file join $lab4_root rtl board ${name}.v]
}
set lab4_sim_files [list [file join $lab4_root sim tb_alu_core.v] [file join $lab4_root sim tb_lab4_top.v]]
set lab4_xdc [file join $lab4_root constraints lab4.xdc]
foreach path [concat $lab4_design_files $lab4_sim_files [list $lab4_xdc]] {
    if {![file isfile $path]} { error "Required package file is missing: $path" }
}
file mkdir $lab4_project_dir
set lab4_open [current_project -quiet]
if {$lab4_open ne ""} {
    if {![string equal -nocase [file normalize [get_property DIRECTORY $lab4_open]] $lab4_project_dir]} {
        error "Close the current project before opening this lab4 package."
    }
} elseif {[file exists $lab4_xpr]} {
    open_project $lab4_xpr
} else {
    create_project $lab4_project_name $lab4_project_dir -part $lab4_part
}
if {[get_property PART [current_project]] ne $lab4_part} {error "Expected device $lab4_part"}
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
foreach {fileset expected} [list sources_1 $lab4_design_files sim_1 $lab4_sim_files constrs_1 [list $lab4_xdc]] {
    set present {}
    foreach item [get_files -quiet -of_objects [get_filesets $fileset]] {
        set full [file normalize [get_property NAME $item]]
        lappend present $full
        foreach needed $expected {
            if {[string equal -nocase [file tail $full] [file tail $needed]] && ![string equal -nocase $full $needed]} {
                error "Conflicting file path in $fileset: $full"
            }
        }
        if {$fileset eq "constrs_1" && ![string equal -nocase $full $lab4_xdc]} {
            error "Use only constraints/lab4.xdc in this project."
        }
    }
    foreach path $expected {
        if {[lsearch -exact -nocase $present $path] < 0} {add_files -fileset $fileset -norecurse $path}
    }
}
set_property used_in_synthesis true [get_files $lab4_xdc]
set_property used_in_implementation true [get_files $lab4_xdc]
set_property top lab4_top [get_filesets sources_1]
set_property top tb_alu_core [get_filesets sim_1]
set_property xsim.simulate.runtime 1000ns [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "LAB4_PROJECT=$lab4_xpr"
puts "DESIGN_TOP=lab4_top"
puts "CONSTRAINT=$lab4_xdc"
