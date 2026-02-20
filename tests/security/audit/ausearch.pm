# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-Later
#
# Summary: Verify the "ausearch" utility can search the audit log file for certain events using various keys or
#          other characteristics of the logged format
# Maintainer: QE Security <none@suse.de>
# Tags: poo#81772, tc#1768578

use base 'opensusebasetest';
use testapi;
use utils;
use version_utils qw(is_sle is_tumbleweed);

sub run {
    my $tmp_output = '/tmp/out';
    my $tmp_backup = '/tmp/backup';
    my $rules_backup = '/tmp/rules';
    my $audit_log = '/var/log/audit/audit.log';

    select_console 'root-console';

    # Make sure audit service is started
    assert_script_run('systemctl is-active auditd');

    # Backup existing rules
    assert_script_run("auditctl -l > $rules_backup");

    # Wipe out all existing audit rules
    assert_script_run("auditctl -D");

    # Add a watch rule for /etc/hostname
    assert_script_run("auditctl -w /etc/hostname");

    # Clean audit logs
    assert_script_run("echo '' > $audit_log");

    # Generate audit records for testing
    # 1. Read /etc/hostname to see if an event is logged
    assert_script_run("cat /etc/hostname");

    # 2. Check if the SUT has apparmor
    # If apparmor is available, the return value is 0
    assert_script_run('systemctl restart apparmor') if script_run('systemctl status apparmor | grep "Active: active"') == 0;

    # Search for an event based on the given filename
    assert_script_run("ausearch -f /etc/hostname > $tmp_output");

    # Extract pid from output log
    script_run("tail -1 $tmp_output > $tmp_backup");

    # todo: refactored (some regexp magic?) that works on all OS versions
    my $cut_index = 7;
    $cut_index = 9 if is_sle('>12-SP5');
    $cut_index = 14 if is_tumbleweed || is_sle('>=16');

    script_run("cat $tmp_backup | cut -d '=' -f $cut_index > $tmp_output");
    my $pid = script_output("cat $tmp_output | cut -d ' ' -f 1");

    # Search for an event matching the given process ID
    assert_script_run("ausearch -p $pid > $tmp_output");

    # Extract event id from output log
    script_run("tail -1 $tmp_output > $tmp_backup");
    script_run("awk -F: '{print \$2}' $tmp_backup > $tmp_output");
    my $event_id = script_output("cat $tmp_output | cut -d ')' -f 1");

    # Search for an event based on the given event ID
    validate_script_output("ausearch --event $event_id | tail -1", sub { m/$event_id/ });

    # Restore rules
    assert_script_run("auditctl -R $rules_backup");

    # On 15-SP3 and lower, there may not be messages that contain 'x86_64'
    if (!is_sle('<=15-SP3')) {
        # Check if the get_pid rule is listed which was added in auditctl.pm
        validate_script_output('auditctl -l', sub { m/get_pid/ });
        # Trigger the get_pid rule
        script_run('ps -q 1');
        # Search for events based on a specific CPU architecture
        validate_script_output("ausearch -i --arch x86_64", sub { m/arch=x86_64/ });
    }
}

1;
