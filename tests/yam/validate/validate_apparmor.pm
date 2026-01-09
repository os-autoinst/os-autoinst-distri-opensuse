# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate apparmor status after agama installation.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use testapi qw(select_console);
use services::apparmor;

sub run {
    select_console 'root-console';

    services::apparmor::check_service();
    services::apparmor::check_aa_status();
}

1;
