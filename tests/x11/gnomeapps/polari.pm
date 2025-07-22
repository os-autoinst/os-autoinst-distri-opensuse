# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: polari
# Summary: GNOME IRC (polari) - Minimal Test
# Maintainer: Dominique Leuenberger <dimstar@suse.de>>

use base "x11test";
use testapi;
use utils;

sub run {
    assert_gui_app('polari');
    # assert_gui_app pressed alt-f4, but that closed 'only' the 'welcome dialog'
    # press once again alt-f4
    send_key('alt-f4');
    assert_and_click('polari-quit');
}

1;
