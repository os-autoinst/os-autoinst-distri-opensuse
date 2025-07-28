# SUSE's openQA tests
#
# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Open the openQA webui in the web browser
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base "x11test";
use testapi;
use x11utils 'ensure_unlocked_desktop';

sub run {
    select_console 'x11';
    ensure_unlocked_desktop();

    x11_start_program("firefox http://localhost", timeout => 60, valid => 0);
    # starting from git might take a bit longer to get and generated assets
    # workaround for poo#19798, basically doubles the timeout
    assert_screen 'openqa-dashboard', 600;
}

sub test_flags {
    return {fatal => 1};
}

sub post_run_hook {
    # do not assert generic desktop
}

1;
