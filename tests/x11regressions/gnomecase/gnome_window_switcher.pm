# Gnome tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use strict;
use testapi;

# Case 1503968 - Gnome: Window Switcher works with ALT+TAB

sub run() {
    my $self = shift;

    # Launch 3 applications
    x11_start_program("nautilus");
    assert_screen 'nautilus-launched';
    send_key "super-h";    # Minimize the window
    x11_start_program("gedit");
    assert_screen 'gedit-launched';
    send_key "super-h";    # Minimize the window
    x11_start_program("gnote");
    assert_screen "gnote-first-launched";
    send_key "super-h";    # Minimize the window

    # Switch windowns with alt+tab
    hold_key "alt";
    send_key "tab";
    assert_screen "alt-tab-gedit";
    send_key "tab";
    assert_screen "alt-tab-nautilus";
    send_key "tab";
    assert_screen "alt-tab-gnote";
    release_key "alt";

    # Close the 3 applications
    send_key "alt-f4";
    wait_still_screen;
    send_key "alt-tab";
    send_key "alt-f4";
    wait_still_screen;
    send_key "alt-tab";
    send_key "alt-f4";
    wait_still_screen;
}

1;
# vim: set sw=4 et:
