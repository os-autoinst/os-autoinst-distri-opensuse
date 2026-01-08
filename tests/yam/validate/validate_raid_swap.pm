# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Validate the /etc/fstab doesn't have md1 as swap but has md0 instead.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_module_consoletest';
use testapi;

sub run {
    select_console 'root-console';

    # Ensure /dev/md0 is not used for swap
    assert_script_run '! swapon --summary | grep -q "^/dev/md0"';

    # Check that swap is on /dev/md1
    assert_script_run 'swapon --summary | grep -q "^/dev/md1"';
}

1;
