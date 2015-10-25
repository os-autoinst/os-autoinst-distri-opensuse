use base "basetest";
use strict;
use testapi;
use utils;

sub run() {
    # we have some tests that waits for dvd boot menu timeout and boot from hdd
    # - the timeout here must cover it
    wait_boot bootloader_time => 80;
}

sub test_flags() {
    return { fatal => 1 };
}

1;
# vim: set sw=4 et:
