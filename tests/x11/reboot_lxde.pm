use base "opensusebasetest";
use testapi;
use utils;

sub run() {
    wait_idle;

    #send_key "ctrl-alt-delete"; # does open task manager instead of reboot
    x11_start_program("xterm");
    script_sudo "/sbin/reboot";
    wait_boot;
}

sub test_flags() {
    return {important => 1, milestone => 1};
}
1;

# vim: set sw=4 et:
