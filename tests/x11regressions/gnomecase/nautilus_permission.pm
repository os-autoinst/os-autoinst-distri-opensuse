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

# case 1436125-use nautilus to change file permissions

sub run() {
    my $self = shift;

    x11_start_program("touch newfile");
    x11_start_program("nautilus");
    send_key_until_needlematch 'nautilus-newfile-matched', 'right', 15;
    send_key "shift-f10";
    assert_screen 'nautilus-rightkey-menu', 3;
    send_key "r";    #choose properties
    assert_screen 'nautilus-properties', 5;
    send_key "up";       #move focus onto tab
    sleep 2;
    send_key "right";    #move to tab Permissions
    for (1 .. 4) { send_key "tab" }
    send_key "ret";
    assert_screen 'nautilus-access-permission', 3;
    send_key "down";
    sleep 1;
    send_key "ret";
    sleep 1;
    send_key "tab";
    sleep 1;
    send_key "ret";
    assert_screen 'nautilus-access-permission', 3;
    send_key "down";
    sleep 1;
    send_key "ret";
    sleep 1;
    send_key "esc";    #close the dialog
    sleep 1;
    #reopen the properties menu to check if the changes kept
    send_key "shift-f10";
    assert_screen 'nautilus-rightkey-menu', 3;
    send_key "r";      #choose properties
    assert_screen 'nautilus-properties', 5;
    send_key "up";       #move focus onto tab
    sleep 2;
    send_key "right";    #move to tab Permissions
    assert_screen 'nautilus-permissions-changed', 3;
    send_key "esc";      #close the dialog


    #clean: remove the created new note
    x11_start_program("rm newfile");
    send_key "ctrl-w";
}

1;
# vim: set sw=4 et:
