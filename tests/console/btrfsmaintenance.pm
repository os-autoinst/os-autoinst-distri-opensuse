# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: btrfsmaintenance
# Summary: Check btrfsmaintenance for functionality
# - run btrfs-balance.sh and btrfs-scrub.sh
# - Check if btrfsmaintenance-refresh.service is present and started properly
# - Check if btrfs-scrub is scheduled
# - Check if btrfs-balance is scheduled
# - Checks for btrfs-related cron jobs after uninstalling btrfsmaintenance
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_leap is_sle);

sub btrfs_service_unavailable {
    my $service = $_[0];
    # Check if the given btrfs service (e.g. scrub or balance) is enabled in one of the following methods:
    # - via btrfsmaintenance-refresh.service
    # - via a systemd timer service
    # - or if known as a timer
    if (script_run("systemctl status btrfsmaintenance-refresh.service | grep -E -v 'uninstall|none' | grep $service") == 0) {
        record_info("btrfs-$service", "btrfs-$service enabled via btrfsmaintenance-refresh.service");
        return 0;
    } elsif (script_run("systemctl is-enabled btrfs-$service.timer") == 0) {
        record_info("btrfs-$service", "btrfs-$service enabled via btrfs-$service.timer");
        return 0;
    } elsif (script_run("systemctl list-timers --all | grep btrfs-$service") == 0) {
        record_info("btrfs-$service", "btrfs-$service found in list-timers");
        return 0;
    } else {
        record_info("btrfs-$service", "btrfs-$service is not enabled");
        return 1;
    }
}

sub run {
    # Preparation
    my $self = shift;
    select_serial_terminal;

    if (script_run('mount | grep btrfs') != 0) {
        record_info("btrfs-maintenance", "No btrfs volume mounted");
    }
    # Run balance and scrub
    assert_script_run('/usr/share/btrfsmaintenance/btrfs-balance.sh', timeout => 300);
    assert_script_run('/usr/share/btrfsmaintenance/btrfs-scrub.sh ', timeout => 300);
    assert_script_run('systemctl restart btrfsmaintenance-refresh.service');
    # Check state of btrfsmaintenance-refresh units. Have to use (|| :) due to pipefail
    assert_script_run('(systemctl is-enabled btrfsmaintenance-refresh.path || :) | grep enabled') unless is_sle("<15");
    # Fixed in SP1:Update, but is out of general support
    if (is_sle("<15-SP2")) {
        assert_script_run('(systemctl is-enabled btrfsmaintenance-refresh.service || :) | grep enabled');
        record_soft_failure('boo#1165780 - Preset is wrong and enables btrfsmaintenance-refresh.service instead of .path');
    } else {
        # Preset is correct, btrfsmaintenance-refresh.service dropped the [Install] section
        assert_script_run('(systemctl is-enabled btrfsmaintenance-refresh.service || :) | grep static');
    }
    # Check if btrfs-scrub and btrfs-balance are (somehow) enabled (results only in a info write)
    if (!is_sle('<15')) {
        die("btrfs-scrub service not active") if btrfs_service_unavailable("scrub");
        die("btrfs-balance service not active") if btrfs_service_unavailable("balance");
    }
    # Check for crontab remnants of btrfsmaintenance after uninstall (see https://bugzilla.suse.com/show_bug.cgi?id=1159891)
    zypper_call 'remove btrfsmaintenance';
    if (script_run("crontab -l") == 0 && script_run('crontab -l | grep btrfs') == 0) {
        script_run('crontab -l | grep btrfs > /var/tmp/btrfs_cron_remnants.txt');
        upload_logs('/var/tmp/btrfs_cron_remnants.txt');
        upload_logs("/etc/sysconfig/btrfsmaintenance", log_name => "sysconfig.txt");
        record_info("btrfsmaintenance", "crontab - btrfs remnants detected");
        die "btrfsmaintenance script failed";
    }
}

sub post_run_hook {
    # Ensure btrfsmaintenance is installed
    zypper_call 'in btrfsmaintenance';
}
1;
