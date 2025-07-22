# SUSE's openQA tests
#
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: brasero
# Summary: Brasero launch and about
# - Run brasero (installs it if necessary)
# - Call help and about and check the window
# - Close help and brasero
# Maintainer: Grace Wang <gwang@suse.com>

use base "x11test";
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    assert_gui_app('brasero', install => !is_sle('<15-SP4'), remain => 1);

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
