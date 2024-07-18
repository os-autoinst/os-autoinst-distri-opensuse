# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: apparmor-utils
# Summary: Test apparmor utilities
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use services::apparmor;

sub is_enabled {
    # according to Linux' Documentation/admin-guide/LSM/index.rst,
    # the current security modules can be found in /sys/kernel/security/lsm
    return script_run 'grep apparmor /sys/kernel/security/lsm' == 0;
}

sub assert_running {
    services::apparmor::check_service();
    services::apparmor::check_aa_status();
}

sub run {
    select_console 'root-console';

    if (not is_enabled) {
        return;
    }

    assert_running;
}

1;
