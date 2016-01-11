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

# Case 1436026 - Evince: View
sub run() {
    my $self = shift;
    x11_start_program("evince " . autoinst_url . "/data/x11regressions/test.pdf");

    send_key "f11";    # fullscreen mode
    assert_screen 'evince-fullscreen-mode', 5;
    send_key "esc";

    send_key "f5";     # presentation mode
    assert_screen 'evince-presentation-mode', 5;
    send_key "esc";

    send_key "ctrl-w";
}

1;
# vim: set sw=4 et:
