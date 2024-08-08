# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: apparmor-utils
# Summary: Test apparmor utilities
# Maintainer: QE-C team <qa-c@suse.de>

use base "consoletest";
use services::apparmor;
use strict;
use testapi;
use utils;
use warnings;

sub run {
    select_console 'root-console';
    my $is_running = (systemctl("status apparmor", ignore_failure => 1) == 0);
    if ($is_running) {
        services::apparmor::check_function;
    }
}

1;
