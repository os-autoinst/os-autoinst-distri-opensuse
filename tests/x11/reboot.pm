use base "x11test";
use testapi;
use utils;

sub run() {
    wait_boot;
}

sub test_flags() {
    return { milestone => 1, important => 1 };
}
1;

# vim: set sw=4 et:
