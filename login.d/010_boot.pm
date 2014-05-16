use base "basetest";
use strict;
use bmwqemu;
use Time::HiRes qw(sleep);

sub is_applicable() {
    return !$vars{UEFI};
}

sub run() {
    assert_screen "inst-bootmenu", 30;
    sleep 2;
    send_key "ret";    # boot

    assert_screen "grub-opensuse-13.1", 15;
    sleep 1;
    send_key "ret";

    assert_screen "desktop-at-first-boot", 300;

}

sub test_flags() {
    return { 'fatal' => 1 };
}

1;
# vim: set sw=4 et:
