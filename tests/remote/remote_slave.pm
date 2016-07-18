# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "opensusebasetest";
use strict;
use testapi;
use lockapi;
use mmapi;

# poo#9576
sub run() {
    # Notice MASTER system is ready for installation
    assert_screen "remote_slave_ready", 200;
    mutex_create "installation_ready";

    # Wait until MASTER finishes installing the system
    wait_for_children;
}

sub test_flags {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
