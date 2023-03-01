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

my $reinstall_btrfsmaintenance = 0;

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

sub btrfs_await_scrub {
    if (is_sle("<15-SP4")) {
        script_retry('btrfs scrub status / | grep -e "scrub started .* and finished after"', retry => 20, delay => 30);
    } else {
        script_retry('btrfs scrub status / | grep -e "Status:.*finished"', retry => 20, delay => 30);
    }
}

sub btrfs_await_balance {
    script_retry('btrfs balance status / | grep -e "No balance found"', retry => 100, delay => 30);
}

sub btrfs_await_trim_service {
    # Note: Need to encapsulate in `bash -c` due to script_retry using `timeout`
    script_retry("bash -c '(systemctl is-active btrfs-trim.service || true) | grep \"inactive\"'", retry => 100, delay => 30);
}

sub run {
    select_serial_terminal;

    die "no btrfs volume present" if (script_output('mount') !~ "btrfs");

    # Check state of btrfsmaintenance-refresh units.
    # On SLES15/TW we use the btrfsmaintenance-refresh.path. On SLES12 we still use the btrfsmaintenance-refresh.service
    if (is_sle("<15")) {
        validate_script_output('systemctl is-enabled btrfsmaintenance-refresh.service || true', qr/enabled/, fail_message => 'btrfsmaintenance-refresh.service must be enabled on SLES12');
    } else {
        validate_script_output('systemctl is-enabled btrfsmaintenance-refresh.path || true', qr/enabled/, fail_message => "btrfsmaintenance-refresh.path must be enabled");

        # On SLES 15-SP1 the service is not yet static.
        if (is_sle("<15-SP2")) {
            validate_script_output('systemctl is-enabled btrfsmaintenance-refresh.service || true', qr/(static|disabled)/, fail_message => 'btrfsmaintenance-refresh.service must be disabled or static');
        } else {
            validate_script_output('systemctl is-enabled btrfsmaintenance-refresh.service || true', qr/static/, fail_message => 'btrfsmaintenance-refresh.service must be static');
        }
    }

    # Check if btrfs-scrub and btrfs-balance are (somehow) enabled (results only in a info write)
    if (!is_sle('<15')) {
        die("btrfs-scrub service not active") if btrfs_service_unavailable("scrub");
        die("btrfs-balance service not active") if btrfs_service_unavailable("balance");
    }

    # Check individual service health
    if (is_sle("<15")) {
        # Ensure the provided scripts work
        assert_script_run('/usr/share/btrfsmaintenance/btrfs-scrub.sh ', timeout => 300);
        assert_script_run('/usr/share/btrfsmaintenance/btrfs-balance.sh', timeout => 300);
    } else {
        # Ensure the provided services work
        assert_script_run('systemctl start btrfs-scrub.service');
        btrfs_await_scrub();
        assert_script_run('systemctl start btrfs-balance.service');
        btrfs_await_balance();
        assert_script_run('systemctl start btrfs-trim.service');
        btrfs_await_trim_service();
        validate_script_output('systemctl status btrfs-trim.service || true', qr/Started Discard unused blocks/, fail_message => "btrfs-trim.service didn't start");
    }

    # Check for crontab remnants of btrfsmaintenance after uninstall (see https://bugzilla.suse.com/show_bug.cgi?id=1159891)
    zypper_call 'remove btrfsmaintenance';
    $reinstall_btrfsmaintenance = 1;
    if (script_run("crontab -l") == 0 && script_run('crontab -l | grep btrfs') == 0) {
        record_soft_failure("bsc#1159891 btrfs remnants present in crontab");
        script_run('crontab -l > /var/tmp/btrfs_cron.txt');
        upload_logs('/var/tmp//var/tmp/btrfs_cron.txt', log_name => "crontab.txt");
        upload_logs("/etc/sysconfig/btrfsmaintenance", log_name => "sysconfig.txt");
        die "btrfsmaintenance remnants present after uninstall";
    }
}

sub post_run_hook {
    # Restore btrfsmaintenance
    zypper_call 'in btrfsmaintenance' if ($reinstall_btrfsmaintenance);
}

sub post_fail_hook {
    # Restore btrfsmaintenance
    zypper_call 'in btrfsmaintenance' if ($reinstall_btrfsmaintenance);
}

1;
