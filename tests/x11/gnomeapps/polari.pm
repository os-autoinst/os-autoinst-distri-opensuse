# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: GNOME IRC (polari) - Minimal Test
# Maintainer: Dominique Leuenberger <dimstar@suse.de>>

use base "x11test";
use strict;
use warnings;
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
