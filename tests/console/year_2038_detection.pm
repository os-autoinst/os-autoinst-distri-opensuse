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
use version_utils qw(is_transactional);
use Utils::Systemd 'disable_and_stop_service';
use power_action_utils 'power_action';
use Utils::Backends 'is_pvm';

sub install_pkg {
    if (is_transactional) {
        trup_call('pkg install chrony');
        check_reboot_changes;
    }
    else {
        zypper_call('in chrony');
    }
}

sub run {
    my $self = shift;
    select_serial_terminal;

    install_pkg if (script_run('rpm -qi chrony') != 0);
    systemctl("start chronyd");    # Ensure chrony is started
    assert_script_run('chronyc makestep');
    record_info('Show current date and time', script_output('date +"%Y-%m-%d"'));
    assert_script_run('utmpdump /var/run/utmp');
    assert_script_run('utmpdump /var/log/wtmp');

    # Stop the chrony service so that we can change date and time
    disable_and_stop_service('chronyd.service');

    # Set the time and date beyond a Y2038
    record_info('Timewarp', script_output('timedatectl status'));
    assert_script_run('timedatectl set-time "2038-01-20 03:14:07"');

    # We may need to logout and login again to make the date/time change
    # However, we need to handle many platforms and different products.
    # Reboot the system to acieve this is a simple way for the time being.
    if (is_transactional) {
        process_reboot(trigger => 1);
    }
    else {
        power_action('reboot', textmode => 1);
        reconnect_mgmt_console if is_pvm;
        $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
    }
    select_serial_terminal;
    record_info("time after reboot", script_output("timedatectl status"));
    my $utmp_output = script_output('utmpdump /var/run/utmp');
    my $wtmp_output = script_output('utmpdump /var/log/wtmp');
    record_soft_failure('bsc#1188626 uttmpdump shows incorrect year for 2038 and beyond') if ($utmp_output !~ m/2038/sx || $wtmp_output !~ m/2038/sx);

    systemctl('start chronyd.service');
    record_info('Show NTP sources', script_output('chronyc -n sources -v'));
    script_retry('chronyc makestep && (date +"%Y-%m-%d" | grep -v 2038)', delay => 60, retry => 3, fail_message => 'Time sync with NTP server failed (poo#127343)');
}

sub post_run_hook {
    my ($self) = shift;
    upload_logs('/var/log/wtmp');
}

1;
