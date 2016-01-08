# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
