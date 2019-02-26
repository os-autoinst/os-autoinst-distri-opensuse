# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: GNOME dconf editor - Minimal Test
# Maintainer: Dominique Leuenberger <dimstar@suse.de>>

use base "x11test";
use strict;
use warnings;
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
