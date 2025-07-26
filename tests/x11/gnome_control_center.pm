# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gnome-control-center
# Summary: Test for gnome-control-center, with panel
# - Login user if necessary
# - Start gnome-control-center and check if it is running
# - Access "about" (if gnome 3.26) otherwise "details"
# - Close gnome-control-center
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>
# Tags: boo#897687

use base "x11test";
use testapi;
use x11utils 'ensure_unlocked_desktop';

sub run {
    # If system update tests were executed, need to switch back to x11
    select_console('x11', await_console => 0);
    ensure_unlocked_desktop;
    mouse_hide(1);
    # for timeout selection see bsc#965857
    x11_start_program('gnome-control-center', match_timeout => 120);
    if (match_has_tag 'gnome-control-center-broken') {
        send_key 'alt-f4';
        wait_still_screen;
        x11_start_program('gnome-control-center', match_timeout => 120);
    }
    # The gnome control center updated, the work flow for non-default page
    # will be same as gnome-control-center-new-layout.
    if (match_has_tag('gnome-control-center-new-layout') || match_has_tag('gnome-control-center-detail-layout')) {
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
