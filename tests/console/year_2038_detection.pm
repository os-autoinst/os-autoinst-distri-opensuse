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
use transactional qw(trup_call check_reboot_changes);
use version_utils qw(is_transactional);

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
    select_serial_terminal;

    install_pkg if (script_run('rpm -qi chrony') != 0);
    systemctl("start chronyd");    # Ensure chrony is started
    assert_script_run 'chronyc makestep';
    record_info('Show current date and time', script_output('date +"%Y-%m-%d"'));
    assert_script_run('utmpdump /var/run/utmp');
    assert_script_run('utmpdump /var/log/wtmp');

    # Stop the chrony service so that we can change date and time
    systemctl('stop chronyd.service');
    # Set the time and date beyond a Y2038
    assert_script_run('timedatectl set-time "2038-01-20 03:14:07"');

    # We may need to logout and login again to make the date/time change
    # take effect. in a simple way, we can switch to another user to
    # achieve this.
    #
    # Create user account, if image doesn't already contain user
    # (which is the case for SLE images that were already prepared by openQA)
    if (script_run("getent passwd $username") != 0) {
        assert_script_run "useradd -m $testapi::username";
        assert_script_run "echo '$testapi::username:$testapi::password' | chpasswd";
    }
    ensure_serialdev_permissions;

    # Switch user to check if the issue can be captured
    select_console 'user-console';
    my $utmp_output = script_output('utmpdump /var/run/utmp');
    my $wtmp_output = script_output('utmpdump /var/log/wtmp');
    record_soft_failure('bsc#1188626 uttmpdump shows incorrect year for 2038 and beyond') if ($utmp_output !~ m/2038/sx || $wtmp_output !~ m/2038/sx);

    # Start the chrony service again
    select_serial_terminal;
    systemctl('start chronyd.service');
    assert_script_run 'chronyc makestep';
    record_info('Show synced date and time', script_output('date +"%Y-%m-%d"'));
}

sub post_run_hook {
    my ($self) = shift;
    upload_logs('/var/log/wtmp');
}

1;
