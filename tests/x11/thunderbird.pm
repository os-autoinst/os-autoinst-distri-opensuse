# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Rework the tests layout.
# G-Maintainer: Alberto Planas <aplanas@suse.com>

use base "x11test";
use strict;
use testapi;

sub run() {
    my $self = shift;
    ensure_installed("MozillaThunderbird");
    x11_start_program("thunderbird");
    assert_screen 'test-thunderbird-1', 3;
    wait_screen_change {
        send_key "alt-f4";    # close wizzard
    };
    send_key "alt-f4";        # close prog
}

1;
# vim: set sw=4 et:
