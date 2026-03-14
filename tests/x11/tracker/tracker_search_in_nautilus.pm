# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: nautilus gedit
# Summary: tracker search in nautilus
# - Launch nautilus
# - Send ctrl-f and type "newfile" on search box
# - Check if gedit or LibreOffiece writer is opened with a new file
# - Close gedit or writer and nautilus
# Maintainer: nick wang <nwang@suse.com>

use base "x11test";
use testapi;
use version_utils 'is_sle';

sub run {
    x11_start_program('nautilus');
    wait_screen_change { send_key 'ctrl-f' };
    type_string 'newfile';
    wait_still_screen 2;
    save_screenshot;
    send_key 'ret';
    if (is_sle('>=15-sp7')) {
        assert_screen 'oowriter';
        send_key "alt-f4" if match_has_tag('popup-welcome-to-libreoffice');
        assert_screen 'writer-launched';
    }
    else {
        assert_screen 'gedit-launched';
    }
    send_key 'alt-f4';
    send_key_until_needlematch('generic-desktop', 'alt-f4', 4, 10);
}

1;
