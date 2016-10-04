# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test for gnome-control-center
#    Identify bugs like https://bugzilla.suse.com/show_bug.cgi?id=897687
#    earlier.
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "x11test";
use strict;
use testapi;

# test gnome-control-center, with panel (boo#897687)

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    mouse_hide(1);
    x11_start_program("gnome-control-center");
    assert_screen "gnome-control-center-started", 120;    # for timeout selection see bsc#965857
    type_string "details";
    assert_screen "gnome-control-center-details-typed";
    assert_and_click "gnome-control-center-details";
    assert_screen 'test-gnome_control_center-1';
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
