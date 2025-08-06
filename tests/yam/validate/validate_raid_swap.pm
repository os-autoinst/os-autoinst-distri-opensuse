# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Validate the /etc/fstab doesn't have md1 as swap but has md0 instead.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_module_consoletest';
use strict;
use warnings;
use testapi;

sub run {
    select_console 'root-console';

    # Check that swap is on /dev/md0
    assert_script_run 'swapon --summary | grep -q "^/dev/md0"';

    # Ensure /dev/md1 is not used for swap
    assert_script_run '! swapon --summary | grep -q "^/dev/md1"';
}

1;
