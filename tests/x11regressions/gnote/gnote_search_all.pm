# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: x11regressions: add test scripts for gnote
# G-Maintainer: Xudong Zhang <xdzhang@suse.com>

use base "x11regressiontest";
use strict;
use testapi;

# case 1436174-test function search all notes

sub run() {
    my $self = shift;

    x11_start_program("gnote");
    assert_screen "gnote-first-launched", 10;
    send_key "ctrl-f";
    sleep 2;
    type_string "welcome";
    assert_screen 'gnote-search-welcome', 5;

    send_key "ctrl-w";
}

1;
# vim: set sw=4 et:
