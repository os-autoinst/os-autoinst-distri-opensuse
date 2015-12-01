use base "consoletest";
use testapi;
use utils;

sub run() {
    become_root;
    type_string "reboot\n";
    reset_consoles;
    wait_boot;
    select_user_console();
    assert_script_sudo "chown $username /dev/$serialdev";
}

sub test_flags() {
    return {milestone => 1, important => 1};
}
1;

# vim: set sw=4 et:
