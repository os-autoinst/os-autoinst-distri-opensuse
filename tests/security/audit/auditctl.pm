# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-Later
#
# Summary: Controlling the Audit system using auditctl
# Maintainer: QE Security <none@suse.de>
# Tags: poo#81772, tc#1768551

use base 'opensusebasetest';
use testapi;
use utils;
use Utils::Architectures 'is_x86_64';

sub run {
    my $audit_rules = '/etc/audit/rules.d/audit.rules';
    my $audit_log = '/var/log/audit/audit.log';

    select_console 'root-console';

    # Disable audit
    validate_script_output('auditctl -e 0', sub { m/enabled 0/ });
    assert_script_run("echo '' > $audit_log");

    # Check if the SUT has apparmor
    # If apparmor is available, the return value is 0
    my $apparmor_status = script_run('systemctl status apparmor | grep "Active: active"');

    if ($apparmor_status == 0) {
        systemctl('restart apparmor');
        script_run("tail -1 $audit_log | grep SERVICE_START")
          ? record_info('Checked: ', 'auditd temporarily disabled as expected')
          : record_info('Error: ', 'unexpected audit log recorded', result => 'fail');
    }

    # Check & enable audit
    validate_script_output('auditctl -s', sub { m/enabled 0/ });
    validate_script_output('auditctl -e 1', sub { m/enabled 1/ });
    assert_script_run("echo '' > $audit_log");

    if ($apparmor_status == 0) {
        systemctl('restart apparmor');
        script_run("tail -1 $audit_log | grep SERVICE_START")
          ? record_info('Error: ', 'auditd failed to record apparmor logs', result => 'fail')
          : record_info('Checked: ', 'auditd temporarily enabled as expected');
    }

    # Check audit status again
    validate_script_output('auditctl -s', sub { m/enabled 1/ });
    validate_script_output('auditctl -l', sub { m/-a never,task/ });
    validate_script_output("cat $audit_rules", sub { m/-a task,never/ });

    # Add a rule which will log the arch in audit logs on x86
    if (is_x86_64) {
        assert_script_run('auditctl -D');
        assert_script_run('auditctl -a always,exit -F arch=x86_64 -S getpid -k get_pid');
    }
}

1;
