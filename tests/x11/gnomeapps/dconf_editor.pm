# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: dconf-editor
# Summary: GNOME dconf editor - Minimal Test
# Maintainer: Dominique Leuenberger <dimstar@suse.de>>

use base "x11test";
use testapi;
use utils;

sub run {
    assert_gui_app('dconf-editor');
    # assert_gui_app tries to terminate the app by pressing alt-f4
    # for dconf-editor, this only closes the "Warning dialog"
    # After that we expect the dconf-main window, which we again
    # terminate with alt-f4
    assert_screen('dconf-editor-mainwindow');
    send_key('alt-f4');
}

1;
