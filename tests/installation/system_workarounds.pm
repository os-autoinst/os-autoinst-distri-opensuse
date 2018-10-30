# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Special handling to get workarounds applied ASAP
# Maintainer: Guillaume GARDET <guillaume@opensuse.org>

use strict;
use testapi;
use base 'opensusebasetest';

sub run {
    select_console('root-console');

    # boo#1105302 - Disable kernel watchdog on aarch64 (for running system and for next boot)
    if (check_var('ARCH', 'aarch64')) {
        record_info('boo#1105302', "Disable kernel watchdog to avoid test failures due to 'watchdog: BUG: soft lockup - CPU#0 stuck for XXs!'");
        assert_script_run('echo 0 > /proc/sys/kernel/watchdog_thresh');
        assert_script_run('echo "kernel.watchdog_thresh = 0" > /etc/sysctl.d/watchdog.conf');
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
