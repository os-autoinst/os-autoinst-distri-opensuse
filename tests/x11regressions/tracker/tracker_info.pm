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

# Case 1436341 - Tracker: tracker info for file

sub run() {
    my $self = shift;
    x11_start_program("xterm");
    script_run "tracker-info newpl.pl";
    sleep 5;
    assert_screen 'tracker-info-newpl';
    send_key "alt-f4";
    sleep 2;    # close xterm
}

1;
# vim: set sw=4 et:
