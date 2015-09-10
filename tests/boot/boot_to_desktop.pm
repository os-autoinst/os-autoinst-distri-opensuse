use base "basetest";
use strict;
use testapi;
use utils;

sub run() {
    wait_boot bootloader_time => 30;
}

sub test_flags() {
    return { 'fatal' => 1 };
}

1;
# vim: set sw=4 et:
