# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "opensusebasetest";
use strict;
use testapi;

sub run {
    my $self = shift;

    assert_screen "bootloader-ofw-yaboot", 15;

    type_string "rescue";
    send_key "ret";

    if (check_screen "keyboardmap-list", 100) {
        type_string "6\n";
    }
    else {
        record_soft_failure;
    }

    # Login as root (no password)
    assert_screen "rescuesystem-login", 120;
    type_string "root\n";

    # Clean the screen
    sleep 1;
    type_string "reset\n";
    assert_screen "rescuesystem-prompt", 4;
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
