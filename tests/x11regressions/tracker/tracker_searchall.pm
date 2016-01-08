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
    x11_start_program("tracker-needle");
    sleep 2;
    wait_idle;
    assert_screen 'tracker-needle-launched';
    send_key "tab";
    wait_idle;
    send_key "tab";
    wait_idle;
    send_key "right";
    wait_idle;
    send_key "ret";
    #switch to search input field
    for (1 .. 4) { send_key "right" }
    type_string "newfile";
    sleep 5;
    assert_screen 'tracker-search-result';
    send_key "alt-f4";
    sleep 2;

}

1;
# vim: set sw=4 et:
