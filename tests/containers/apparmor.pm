# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: apparmor-utils
# Summary: Test if apparmor is running
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use services::apparmor;

sub run {
    select_console 'root-console';
    services::apparmor::check_service();
    services::apparmor::check_aa_status();
}

1;
