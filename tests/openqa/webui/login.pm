# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Login to the openQA webui
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base "x11test";
use testapi;

sub run {
    assert_and_click 'openqa-login';
    assert_screen 'openqa-logged-in';
}

sub test_flags {
    return {fatal => 1};
}

sub post_run_hook {
    # do not assert generic desktop
}

1;
