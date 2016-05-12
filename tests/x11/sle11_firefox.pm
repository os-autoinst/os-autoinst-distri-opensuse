# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "firefox";
use strict;
use testapi;

sub start_firefox() {
    x11_start_program("firefox", 6, {valid => 1});
    assert_screen 'test-firefox-1', 60;
    if (check_var('DESKTOP', 'kde')) {
        # uncheck Always perform default browser check, firefox audio without default browser check
        send_key 'alt-y';    # accept firefox as default browser
    }
}

1;
# vim: set sw=4 et:
