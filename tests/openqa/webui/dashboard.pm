# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Open the openQA webui in the web browser
# Maintainer: Dominik Heidler <dheidler@suse.de>

use strict;
use base "x11test";
use testapi;
use utils;

sub run {
    select_console 'x11';
    ensure_unlocked_desktop();

    x11_start_program("firefox http://localhost", timeout => 60, valid => 0);
    # starting from git might take a bit longer to get and generated assets
    # workaround for poo#19798, basically doubles the timeout
    if ((check_screen 'openqa-dashboard', 180) == undef) {
        record_info 'ff took to long to start';
    }
    #wait few minutes for ff to start and then fail the test
    assert_screen 'openqa-dashboard', 360;
}

sub test_flags {
    return {fatal => 1};
}

sub post_run_hook {
    # do not assert generic desktop
}

1;
