# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Special handling to get workarounds applied ASAP
# Maintainer: Guillaume GARDET <guillaume@opensuse.org>

use testapi;
use Utils::Architectures;
use base 'opensusebasetest';

sub run {
    select_console('root-console');

    # boo#1105302 - Disable kernel watchdog on aarch64 (for running system and for next boot)
    if (is_aarch64) {
        record_info('boo#1105302', "Disable kernel watchdog to avoid test failures due to 'watchdog: BUG: soft lockup - CPU#0 stuck for XXs!'");
        assert_script_run('echo 0 > /proc/sys/kernel/watchdog_thresh');
        assert_script_run('echo "kernel.watchdog_thresh = 0" > /etc/sysctl.d/watchdog.conf');
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
