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
use utils;

# Preparation for testing pidgin
sub pidgin_preparation() {
    my $self = shift;
    mouse_hide(1);
    my @packages = qw/pidgin/;

    # Install packages
    ensure_installed(@packages);

    # Enable the showoffline
    x11_start_program("pidgin");
    assert_screen "pidgin-welcome";
    send_key "alt-c";

    # pidgin main winodow is hidden in tray at first run
    # need to show up the main window
    if (sle_version_at_least('12-SP2')) {
        hold_key "ctrl-alt";
        send_key "tab";
        wait_still_screen;
        send_key "tab";
        wait_still_screen;
        send_key "tab";
        assert_screen "status-icons";
        release_key "ctrl-alt";
        assert_and_click "status-icons-pidgin";
    }
    else {
        send_key "super-m";
        wait_still_screen;
        send_key "ret";
        wait_still_screen;
    }

    # check showoffline status is off
    send_key "alt-b";
    wait_still_screen;
    send_key "o";
    assert_screen "pidgin-showoffline-off";
    # enable showoffline
    send_key "o";
    wait_still_screen;
    # check showoffline status is on
    send_key "alt-b";
    wait_still_screen;
    send_key "o";
    assert_screen "pidgin-showoffline-on";
    send_key "esc";

    send_key "ctrl-q";    # quit pidgin
}

sub run() {
    my $self = shift;
    pidgin_preparation;
}

1;
# vim: set sw=4 et:
