open_hw_manager
connect_hw_server -url localhost:3121

puts "\n========== HARDWARE TARGETS =========="

set targets [get_hw_targets]

if {[llength $targets] == 0} {
    error "????? JTAG ???????? USB ?????????"
}

foreach target $targets {
    puts "\n========== TARGET =========="
    puts "TARGET_NAME=$target"
    report_property -all $target

    open_hw_target $target
    refresh_hw_target $target

    puts "\n========== FPGA DEVICES =========="

    set devices [get_hw_devices]
    puts "DEVICE_COUNT=[llength $devices]"

    foreach dev $devices {
        puts "\n========== DEVICE DETAIL =========="
        puts "DEVICE_NAME=$dev"
        report_property -all $dev
    }

    report_hw_targets
    close_hw_target $target
}

close_hw_manager
puts "\n========== SCAN COMPLETE =========="
exit
