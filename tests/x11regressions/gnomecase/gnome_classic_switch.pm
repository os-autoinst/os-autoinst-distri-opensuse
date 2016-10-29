# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Gnome: switch between gnome(now default is sle-classic) and gnome-classic
# Maintainer: xiaojun <xjin@suse.com>
# Tags: tc#5255-1503849

use base "x11regressiontest";
use strict;
use testapi;
use utils;

# try some application could be launched successfully
sub application_test {
    x11_start_program "gnome-terminal";
    assert_screen "gnome-terminal-launched";
    send_key "alt-f4";
    send_key "ret";
    wait_still_screen;

    x11_start_program "firefox";
    assert_screen "firefox-gnome", 150;
    send_key "alt-f4";
    wait_still_screen;
    send_key "ret";
    wait_still_screen;
}

sub run () {
    my $self = shift;

    # swith to gnome-classic and try some applications
    assert_screen "generic-desktop";
    switch_wm;
    assert_and_click "displaymanager-settings";
    assert_and_click "dm-gnome-classic";
    send_key "ret";
    assert_screen "desktop-gnome-classic", 120;
    application_test;

    # swith back to default -'sle-classic' and try some applications
    switch_wm;
    assert_and_click "displaymanager-settings";
    assert_and_click "dm-sle-classic";
    send_key "ret";
    assert_screen "generic-desktop", 120;
    application_test;
}

1;
# vim: set sw=4 et:
