# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test the KDE text editor can be installed, started, typing works
#   and closed
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use testapi;

sub run() {
    ensure_installed("kate");
    x11_start_program("kate", 6, {valid => 1});
    assert_screen 'test-kate-1', 10;

    if (!get_var("PLASMA5")) {
        # close welcome screen
        send_key 'alt-c';
        sleep 2;
    }
    type_string "If you can see this text kate is working.\n";
    assert_screen 'test-kate-2', 5;
    send_key "ctrl-q";
    assert_screen 'test-kate-3', 5;
    send_key "alt-d";    # discard
}

1;
# vim: set sw=4 et:
