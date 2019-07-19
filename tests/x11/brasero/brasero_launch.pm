# SUSE's openQA tests
#
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Brasero launch and about
# - Run brasero (installs it if necessary)
# - Call help and about and check the window
# - Close help and brasero
# Maintainer: Grace Wang <gwang@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    assert_gui_app('brasero', install => !is_sle, remain => 1);

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
