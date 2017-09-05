# SUSE's openQA tests
#
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Brasero launch and about
# Maintainer: Grace Wang <gwang@suse.com>

use base "x11regressiontest";
use strict;
use testapi;
use utils;

sub run {
    assert_gui_app('brasero', install => 1, remain => 1);

    # check about window
    send_key 'alt-h';
    wait_still_screen 3;
    send_key 'a';
    assert_screen 'brasero-help-about';
    send_key 'alt-f4';
    wait_still_screen 3;
    send_key 'alt-f4';
}

1;
# vim: set sw=4 et:
