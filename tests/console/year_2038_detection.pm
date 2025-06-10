# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Monitor Year 2038 problem, but so far no fix is required due to
# https://bugzilla.suse.com/show_bug.cgi?id=1188626
#
# The Year 2038 (Y2038) problem relates to representing time in many digital systems
# as the number of seconds passed since 00:00:00 UTC on 1 January 1970 and storing it
# as a signed 32-bit integer. Such implementations cannot encode times after
# 03:14:07 UTC on 19 January 2038. Similar to the Y2K problem, the Year 2038 problem
# is caused by insufficient capacity used to represent time.
#
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use serial_terminal 'select_serial_terminal';
use transactional qw(trup_call check_reboot_changes process_reboot);
use version_utils qw(is_transactional is_sle is_sle_micro is_leap is_leap_micro);
use Utils::Architectures qw(is_s390x);
use Utils::Systemd 'disable_and_stop_service';
use power_action_utils 'power_action';
use Utils::Backends 'is_pvm';
use package_utils;

sub reboot_system {
    my ($self) = @_;
    if (is_transactional) {
        process_reboot(trigger => 1);
    }
    else {
        power_action('reboot', textmode => 1);
        reconnect_mgmt_console if is_pvm;
        $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 400);
    }
    select_serial_terminal;
}

sub run {
    my $self = shift;
    select_serial_terminal;

    install_package('chrony', trup_reboot => 1) if script_run('rpm -qi chrony') != 0;
    systemctl("start chronyd");    # Ensure chrony is started
    assert_script_run('chronyc makestep');
    my $date = script_output('date +"%Y-%m-%d %H:%M:%S"');
    record_info('Show current date and time', "$date");
    # Use LC_TIME=C.UTF-8 to force full date output including the year
    assert_script_run('LC_TIME=C.UTF-8 who');
    assert_script_run('last -F');

    # Stop the chrony service so that we can change date and time
    disable_and_stop_service('chronyd.service');

    # Set the time and date beyond a Y2038
    record_info('Timewarp', script_output('timedatectl status'));
    assert_script_run('timedatectl set-time "2038-01-20 03:14:07"');

    # Trigger a reboot to make the date/time change fully effective and
    # generate some last/who entries.
    $self->reboot_system;
    record_info("time after reboot", script_output("timedatectl status"));
    my $utmp_output = script_output('LC_TIME=C.UTF-8 who');
    my $wtmp_output = script_output('last -F');
    if ($utmp_output !~ m/2038/sx || $wtmp_output !~ m/2038/sx) {
        # bsc#1237773 manual time changes will not persist after reboot on s390 due to no real time clock
        if (is_sle('<16') || is_leap('<16.0') || is_sle_micro || is_leap_micro || is_s390x) {
            record_info("bsc#1188626", "SLE <= 15 not Y2038 compatible");
        }
        else {
            die('Not Y2038 compatible');
        }
    }
    systemctl('start chronyd.service');
    record_info('Show NTP sources', script_output('chronyc -n sources -v -a'));

    # We may need to add some workaround due to poo#127343:
    # wait for chronyd service to check the system clock change;
    # add some timeout after 'chronyc makestep'
    script_retry('journalctl -u chronyd | grep -e "System clock wrong" -e "Received KoD RATE"', delay => 60, retry => 3, die => 0);
    assert_script_run('chronyc makestep');
    unless (script_retry('date +"%Y-%m-%d" | grep -v 2038', delay => 5, retry => 5, die => 0) == 0) {
        record_info("poo#127343", "Time sync with NTP server failed");
        systemctl('stop chronyd.service');
        # Set time stamp when we start the test
        assert_script_run("timedatectl set-time \"$date\"");
        # Sync time with a public ntp server
        assert_script_run("chronyd -q 'server 0.europe.pool.ntp.org iburst'");
        systemctl('start chronyd.service');
        record_info('Current time', script_output('date'));
        # Reboot the system then restore all default configuration
        $self->reboot_system;
    }
}

sub test_flags {
    return {always_rollback => 1};
}

1;
