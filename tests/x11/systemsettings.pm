# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use strict;
use testapi;

sub run() {
    my $self = shift;
    x11_start_program("systemsettings", 6, {valid => 1});
    if (get_var("LIVETEST")) {
        assert_screen 'test-systemsettings-1', 15;
    }
    else {
        assert_screen 'test-systemsettings-1', 3;
    }
    send_key "alt-f4";
    sleep 2;
}

1;
# vim: set sw=4 et:
