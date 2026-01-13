# SUSE's openQA tests
#
# Copyright 2016-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test rolling back to original system version after
#          migration, using transactional-update rollback.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use testapi;
use utils;
use version_utils 'verify_os_version';
use transactional 'process_reboot';

sub run {
    my ($self) = @_;
    process_reboot(trigger => 1);
    select_console 'root-console';
    verify_os_version;
    script_run("transactional-update rollback last");
    process_reboot(trigger => 1);
    select_console 'root-console';
    my $rollback_version = get_var("FROM_VERSION");
    verify_os_version($rollback_version);
}

sub test_flags {
    return {fatal => 1};
}

1;
