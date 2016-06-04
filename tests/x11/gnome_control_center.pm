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
use utils;

# test gnome-control-center, with panel (boo#897687)

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    mouse_hide(1);
    x11_start_program("gnome-control-center");
    assert_screen "gnome-control-center-started", 60;    # for timeout selection see bsc#965857
    type_string "details";
    assert_screen_with_soft_timeout("gnome-control-center-details-typed", soft_timeout => 5);
    assert_and_click "gnome-control-center-details";
    assert_screen_with_soft_timeout('test-gnome_control_center-1', soft_timeout => 3);
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
