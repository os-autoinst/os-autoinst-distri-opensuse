# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: cronie
# Summary: Check for CRON daemon
# - check if cron is enabled
# - check if cron is active
# - check cron status
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle is_public_cloud is_opensuse);

sub run {
    select_serial_terminal;

    # Ensuring ntp-wait is done syncing to avoid cron starting issue bsc#1207042
    if ((is_sle("<15")) && (!is_public_cloud)) {
        script_retry("systemctl is-active ntp-wait.service | grep -vq 'activating'", retry => 10, delay => 60, fail_message => "ntp-wait did not finish syncing");
    }
    # cronie is not installed by default on sle16 and on openSUSE for agama based installations
    if (is_sle('>=16') || (is_opensuse && check_var('AGAMA', 1))) {
        zypper_call('in cronie');
        systemctl('enable cron');
        systemctl('start cron');
    }
    # check if cronie is installed, enabled and running
    assert_script_run 'rpm -q cronie';
    systemctl 'is-enabled cron';
    script_retry 'systemctl is-active cron', retry => 3, delay => 10;
    systemctl 'status cron';
}

1;

