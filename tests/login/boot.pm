use base "basetest";
use strict;
use testapi;
use Time::HiRes qw(sleep);

sub run() {
    assert_screen "inst-bootmenu", 30;
    sleep 2;
    send_key "ret";    # boot

    assert_screen "grub-opensuse-13.1", 15;
    sleep 1;
    send_key "ret";

    assert_screen "generic-desktop", 300;

}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
