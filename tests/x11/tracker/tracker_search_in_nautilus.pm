# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: nautilus gedit
# Summary: tracker search in nautilus
# - Launch nautilus
# - Send ctrl-f and type "newfile" on search box
# - Check if gedit is opened with a new file
# - Close gedit and nautilus
# Maintainer: nick wang <nwang@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    x11_start_program('nautilus');
    wait_screen_change { send_key 'ctrl-f' };
    type_string 'newfile';
    wait_still_screen 2;
    save_screenshot;
    send_key 'ret';
    assert_screen 'gedit-launched';    # should open file newfile
    send_key 'alt-f4';
    send_key_until_needlematch('generic-desktop', 'alt-f4', 4, 10);
}

1;
