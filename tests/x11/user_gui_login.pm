# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Login as user test https://progress.opensuse.org/issues/13306
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "x11test";
use strict;
use testapi;
use utils 'handle_login';

sub run() {
    # hide mouse for clean logout needles
    mouse_hide();
    # logout
    if (check_var('DESKTOP', 'gnome') || check_var('DESKTOP', 'lxde')) {
        my $command = check_var('DESKTOP', 'gnome') ? 'gnome-session-quit' : 'lxsession-logout';
        x11_start_program("$command");    # opens logout dialog
        assert_screen 'logoutdialog' unless check_var('DESKTOP', 'gnome');
    }
    else {
        my $key = check_var('DESKTOP', 'xfce') ? 'alt-f4' : 'ctrl-alt-delete';
        send_key_until_needlematch 'logoutdialog', "$key";    # opens logout dialog
    }
    assert_and_click 'logout-button';                         # press logout
    handle_login;
    assert_screen 'generic-desktop', 90;    # x11test is checking generic-desktop in post_run_hook but after login it can take longer than 30 sec
}

1;
# vim: set sw=4 et:
