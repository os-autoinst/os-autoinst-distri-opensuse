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

use Mojo::Base 'x11test';
use testapi;
use version_utils 'is_tumbleweed';

sub run {
    x11_start_program('touch newfile', valid => 0);
    x11_start_program('nautilus');
    assert_and_click('nautilus-newfile-matched', button => 'right');
    assert_screen 'nautilus-rightkey-menu';
    send_key "r";    #choose properties
    assert_screen 'nautilus-properties';
    assert_and_click 'nautilus-maxmize-properties' if is_tumbleweed;
    assert_and_click 'nautilus-access-permission';
    assert_and_click 'nautilus-default-group-access-permission';
    assert_and_click 'nautilus-read-write-permission';
    assert_and_click 'nautilus-default-other-access-permission';
    assert_and_click 'nautilus-read-write-permission';
    send_key "esc";    #close the custom permissions dialog
    send_key "esc";    #close the dialog
    assert_and_click('nautilus-newfile-matched', button => 'right');
    assert_screen 'nautilus-rightkey-menu';
    send_key "r";    #choose properties
    assert_screen 'nautilus-properties';
    assert_and_click 'nautilus-maxmize-properties' if is_tumbleweed;
    assert_and_click 'nautilus-access-permission';
    assert_screen 'nautilus-permissions-changed';
    send_key "esc";    #close the custom permissions dialog
    send_key "esc";    #close the dialog

    #clean: remove the created new note
    x11_start_program('rm newfile', valid => 0);
    assert_and_click 'nautilus-close-window';
}

1;
