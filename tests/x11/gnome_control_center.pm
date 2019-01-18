# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test for gnome-control-center, with panel
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>
# Tags: boo#897687

use base "x11test";
use strict;
use warnings;
use testapi;
use x11utils 'ensure_unlocked_desktop';

sub run {
    # If system update tests were executed, need to switch back to x11
    select_console('x11', await_console => 0);
    ensure_unlocked_desktop;
    mouse_hide(1);
    # for timeout selection see bsc#965857
    x11_start_program('gnome-control-center', match_timeout => 120);
    if (match_has_tag('gnome-control-center-new-layout')) {
        # with GNOME 3.26, the control-center got a different layout / workflow
        type_string "about";
        assert_screen "gnome-control-center-about-typed";
        assert_and_click "gnome-control-center-about";
    }
    else {
        type_string "details";
        assert_screen "gnome-control-center-details-typed";
        assert_and_click "gnome-control-center-details";
    }
    assert_screen 'test-gnome_control_center-1';
    send_key "alt-f4";
}

1;
