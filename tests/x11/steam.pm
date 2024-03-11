# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: steam
# Summary: steam GUI app startup test
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use strict;
use warnings;
use testapi;
use utils;
use x11utils 'turn_off_gnome_screensaver';

sub run {
    select_console 'x11';
    ensure_installed 'steam';
    x11_start_program('xterm');
    turn_off_gnome_screensaver;
    # start steam in terminal to watch the progress on initial startup, e.g.
    # the update progress
    script_run 'steam', 0;
    assert_screen([qw(steam-accept-agreement steam-login steam-startup-libgl_error)], 600);
    if (match_has_tag('steam-accept-agreement')) {
        assert_and_click 'steam-accept-agreement';
        assert_and_click 'steam-agreement-ok';
        assert_screen([qw(steam-login steam-startup-libgl_error)], 600);
    }
    if (match_has_tag 'steam-startup-libgl_error') {
        # https://github.com/ValveSoftware/steam-for-linux/issues/4768
        # https://wiki.archlinux.org/index.php/Steam/Troubleshooting#Steam_runtime
        # apply workaround from
        # https://askubuntu.com/questions/614422/problem-with-installing-steam-on-ubuntu-15-04
        send_key 'ctrl-c';
        script_run 'clear', 0;
        assert_screen 'xterm';
        assert_script_run
'find $HOME/.steam/root/ubuntu12_32/steam-runtime/*/usr/lib/ \( -name "libstdc++.so.6" -o -name "libgpg-error.so.0" -o -name "libxcb.so.1" -o -name "libgcc_s.so.1" \) -exec mv "{}" "{}.bak" \; -print';
        script_run 'steam', 0;
    }
    # record_soft_failure for issue with steamAPI_Init
    assert_screen [qw(steam-login steamapi-init-failed)], 600;
    if (match_has_tag 'steamapi-init-failed') {
        send_key 'alt-f4';
        record_soft_failure 'bsc#1102525, steamAPI_Init failed';
    }
    wait_screen_change { send_key 'alt-f4' };

    # Make sure the focus is on xterm before closing it
    # https://progress.opensuse.org/issues/156886
    click_lastmatch if check_screen('steam_xterm_stuck', 10);
    script_run 'exit', 0;
}

1;
