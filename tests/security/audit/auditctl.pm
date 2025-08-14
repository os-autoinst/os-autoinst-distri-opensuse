# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-Later
#
# Summary: Controlling the Audit system using auditctl
# Maintainer: QE Security <none@suse.de>
# Tags: poo#81772, tc#1768551

use base 'opensusebasetest';
use testapi;
use utils;
use Utils::Architectures qw(is_x86_64);
use version_utils;

sub run {
    my $audit_rules = '/etc/audit/rules.d/audit.rules';
    my $audit_log = '/var/log/audit/audit.log';
    my $ret = '';

    select_console 'root-console';

    # Disable audit
    validate_script_output('auditctl -e 0', sub { m/enabled 0/ });

    # Make sure auditctl indeed disabled auditd
    assert_script_run("echo '' > $audit_log");

    if (is_sle('<16')) {
        systemctl('restart apparmor');

        $ret = script_run("tail -1 $audit_log | grep SERVICE_START");
        if ($ret == 0) {
            # $ret == 0, report error since there should be no audit logs related to apparmor restart
            record_info('Error: ', 'unexpected audit log recorded', result => 'fail');
        } else {
            # $ret == 1 is the expected return value
            record_info('Checked: ', 'auditd temporarily disabled as expected');
        }
    }

    # Check audit status
    validate_script_output('auditctl -s', sub { m/enabled 0/ });

    # Enable audit
    validate_script_output('auditctl -e 1', sub { m/enabled 1/ });

    # Make sure auditctl indeed enabled auditd
    assert_script_run("echo '' > $audit_log");

    if (is_sle('<16')) {
        systemctl('restart apparmor');

        $ret = script_run("tail -1 $audit_log | grep SERVICE_START");
        if ($ret == 0) {
            # $ret == 0 is the expected return value showing that auditd is enabled now
            record_info('Checked: ', 'auditd temporarily enabled as expected');
        } else {
            # $ret == 1, report error that apparmor log has not been recorded
            record_info('Error: ', 'auditd failed to record apparmor logs', result => 'fail');
        }
    }

    # Check audit status again
    validate_script_output('auditctl -s', sub { m/enabled 1/ });

    # List all rules by default
    validate_script_output('auditctl -l', sub { m/-a never,task/ });

    # Double check the audit rule file
    validate_script_output("cat $audit_rules", sub { m/-a task,never/ });

    # Add a rule which will log the arch in audit logs on x86
    if (is_x86_64) {
        # Delete all existing rules
        assert_script_run('auditctl -D');

        my $pid_rule = 'auditctl -a always,exit -F arch=x86_64 -S getpid -k get_pid';
        # Add the pid_rule
        assert_script_run($pid_rule);
    }
}

1;
