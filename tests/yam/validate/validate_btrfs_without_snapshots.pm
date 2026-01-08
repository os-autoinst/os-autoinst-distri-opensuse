# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that the snapshot is not configured for Btrfs without snapshots

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use testapi;

sub run {
    select_console 'root-console';

    assert_script_run('! snapper list');
    assert_script_run(qq{snapper list 2>&1 | grep "The config 'root' does not exist. Likely snapper is not configured."});
}

1;
