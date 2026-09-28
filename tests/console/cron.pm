# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: cronie
# Summary: Check for CRON daemon
# - check if cron is enabled
# - check if cron is active
# - check cron status
# Maintainer: Dominik Heidler <dheidler@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use package_utils 'install_package';
use version_utils qw(is_sle is_public_cloud is_opensuse is_leap);

sub run {
    select_serial_terminal;

    # Ensuring ntp-wait/chrony-wait is done syncing to avoid cron starting issue bsc#1207042
    unless (is_public_cloud) {
        my $wait_service = is_sle('<15') ? 'ntp-wait' : 'chrony-wait';
        script_retry("systemctl is-active $wait_service.service | grep -vq 'activating'", retry => 10, delay => 60, fail_message => "$wait_service did not finish syncing");
    }
    # cronie is only installed by default on sle/leap < 16
    unless (is_sle('<16') || is_leap('<16')) {
        install_package('cronie', trup_reboot => 1);
        systemctl('enable cron');
        systemctl('start cron');
    }
    # check if cronie is installed, enabled and running
    assert_script_run 'rpm -q cronie';
    systemctl 'is-enabled cron';
    script_retry 'systemctl is-active cron', retry => 6, delay => 10;
    systemctl 'status cron';
}

1;

