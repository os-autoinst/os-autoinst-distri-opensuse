use base "consoletest";
use testapi;
use utils;
use ttylogin;

sub run() {
    become_root;
    type_string "reboot\n";
    wait_boot;
    ttylogin;
    type_string "PS1=\$\n";    # set constant shell promt
}

sub test_flags() {
    return { milestone => 1, important => 1 };
}
1;

# vim: set sw=4 et:
