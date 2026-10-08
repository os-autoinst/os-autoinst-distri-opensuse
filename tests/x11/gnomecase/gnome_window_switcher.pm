# Gnome tests
#
# Copyright 2016-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: nautilus gedit totem
# Summary: Case 1503968 - Gnome: Window Switcher works with ALT+TAB
# - Launch nautilus and minimize
# - Launch gedit and minimize
# - Launch totem and minimize
# - Switch windows using ALT-TAB and check
# - Switch windows using ALT-TAB and close applications using ALT-F4
# Maintainer: Zhaocong Jia <zcjia@suse.com> Grace Wang <grace.wang@suse.com>

use Mojo::Base 'x11test';
use testapi;
use version_utils qw(is_sle);
use x11utils;

sub run {
    # Launch 3 applications
    my $editor = is_sle(">=16.0") ? "gnome-text-editor" : "gedit";
    ensure_installed($editor);
    x11_start_program('nautilus');
    send_key "super-h";    # Minimize the window
    x11_start_program($editor);
    send_key "super-h";    # Minimize the window
    x11_start_program(default_gui_terminal);
    send_key "super-h";    # Minimize the window

    # Switch windowns with alt+tab
    hold_key "alt";
    send_key "tab";
    assert_screen "alt-tab-$editor";
    send_key "tab";
    assert_screen "alt-tab-nautilus";
    send_key "tab";
    assert_screen "alt-tab-terminal";
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
