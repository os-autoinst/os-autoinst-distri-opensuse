# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: nautilus
# Summary: case 1436125-use nautilus to change file permissions
# - Create a test file called "newfile"
# - Launch nautilus
# - Right click "newfile" (or send "SHIFT-F10") and check
# - Send "r" (properties)
# - Open permissions tab and change some permitions
# - Close nautilus dialog
# - Right click, open permissions again, check if permittions were changed
# - Close nautilus
# Maintainer: Grace Wang <grace.wang@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use version_utils qw(is_sle is_leap is_tumbleweed);


sub run {
    x11_start_program('touch newfile', valid => 0);
    x11_start_program('nautilus');
    send_key_until_needlematch 'nautilus-newfile-matched', 'right', 16;
    if (is_sle('15+') || is_leap('15.0+') || is_tumbleweed) {
        assert_and_click('nautilus-newfile-matched', button => 'right');
        record_soft_failure 'boo#1074057 qemu can not properly capture some keys in nautilus under GNOME wayland';
    }
    else {
        send_key "shift-f10";
    }
    assert_screen 'nautilus-rightkey-menu';
    send_key "r";    #choose properties
    assert_screen 'nautilus-properties';
    assert_and_click 'nautilus-access-permission';
    assert_and_click 'nautilus-default-group-access-permission';
    assert_and_click 'nautilus-read-write-permission';
    assert_and_click 'nautilus-default-other-access-permission';
    assert_and_click 'nautilus-read-write-permission';
    send_key "esc";    #close the dialog
                       #reopen the properties menu to check if the changes kept
    if (is_sle('15+') || is_leap('15.0+') || is_tumbleweed) {
        assert_and_click('nautilus-newfile-matched', button => 'right');
    }
    else {
        send_key "shift-f10";
    }
    assert_screen 'nautilus-rightkey-menu';
    send_key "r";    #choose properties
    assert_screen 'nautilus-properties';
    assert_and_click 'nautilus-access-permission';
    assert_screen 'nautilus-permissions-changed';
    send_key "esc";    #close the dialog

    #clean: remove the created new note
    x11_start_program('rm newfile', valid => 0);
    assert_and_click 'nautilus-close-window';
}

1;
