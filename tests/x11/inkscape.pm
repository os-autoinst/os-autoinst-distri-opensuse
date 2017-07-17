# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test inkscape can be installed and started
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use testapi;

sub run {
    ensure_installed('inkscape', timeout => 300);
    x11_start_program("inkscape");
    assert_screen 'test-inkscape-1', 3;
    send_key "alt-f4";    # Exit
}

1;
# vim: set sw=4 et:
