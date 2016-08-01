# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11regressiontest";
use strict;
use testapi;

# Case 1436342 - Tracker: search application in tracker and open it

sub run() {
    my $self = shift;
    x11_start_program("tracker-needle");
    sleep 2;
    wait_idle;    # extra wait because oo sometimes appears to be idle during start
    assert_screen 'tracker-needle-launched';
    type_string "cheese";
    sleep 8;
    assert_screen 'tracker-search-cheese';
    sleep 2;
    send_key "tab";
    sleep 2;
    send_key "down";
    sleep 2;
    send_key "ret";
    sleep 2;
    wait_idle;
    assert_screen 'cheese-launched';
    send_key "alt-f4";
    sleep 2;    #close cheese
    send_key "alt-f4";

}

1;
# vim: set sw=4 et:
