# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: case 1436125-use nautilus to change file permissions
# Maintainer: Xudong Zhang <xdzhang@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use version_utils qw(is_sle is_leap is_tumbleweed);


sub run {
    x11_start_program('touch newfile', valid => 0);
    x11_start_program('nautilus');
    send_key_until_needlematch 'nautilus-newfile-matched', 'right', 15;
    if (is_sle('15+') || is_leap('15.0+') || is_tumbleweed) {
        assert_and_click 'nautilus-newfile-matched', 'right';
        record_soft_failure 'boo#1074057 qemu can not properly capture some keys in nautilus under GNOME wayland';
    }
    else {
        send_key "shift-f10";
    }
    assert_screen 'nautilus-rightkey-menu';
    send_key "r";    #choose properties
    assert_screen 'nautilus-properties';
    send_key "up";       #move focus onto tab
    send_key "right";    #move to tab Permissions
    for (1 .. 4) { send_key "tab" }
    send_key "ret";
    assert_screen 'nautilus-access-permission';
    send_key "down";
    send_key "ret";
    send_key "tab";
    send_key "ret";
    assert_screen 'nautilus-access-permission';
    send_key "down";
    send_key "ret";
    send_key "esc";      #close the dialog
                         #reopen the properties menu to check if the changes kept
    if (is_sle('15+') || is_leap('15.0+') || is_tumbleweed) {
        assert_and_click 'nautilus-newfile-matched', 'right';
    }
    else {
        send_key "shift-f10";
    }
    assert_screen 'nautilus-rightkey-menu';
    send_key "r";        #choose properties
    assert_screen 'nautilus-properties';
    send_key "up";       #move focus onto tab
    send_key "right";    #move to tab Permissions
    assert_screen 'nautilus-permissions-changed';
    send_key "esc";      #close the dialog


    #clean: remove the created new note
    x11_start_program('rm newfile', valid => 0);
    send_key "ctrl-w";
}

1;
