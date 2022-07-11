# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-Later
#
# Summary: Verify the "ausearch" utility can search the audit log file for certain events using various keys or
#          other characteristics of the logged format
# Maintainer: llzhao <llzhao@suse.com>, shawnhao <weixuan.hao@suse.com>
# Tags: poo#81772, tc#1768578

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    my $tmp_output = '/tmp/out';
    my $tmp_backup = '/tmp/backup';
    my $audit_log = '/var/log/audit/audit.log';

    select_console 'root-console';

    # Make sure audit service is started
    assert_script_run('systemctl is-active auditd');

    # Generate audit records for testing
    assert_script_run("echo '' > $audit_log");
    assert_script_run('systemctl stop apparmor');
    assert_script_run('systemctl start apparmor');

    # Search for an event based on the given filename
    assert_script_run("ausearch -f /etc > $tmp_output");

    # Extract pid from output log
    script_run("tail -1 $tmp_output > $tmp_backup");
    my $cut_index = is_sle('<=12-SP5') ? 7 : 9;
    script_run("cat $tmp_backup | cut -d '=' -f $cut_index > $tmp_output");
    my $pid = script_output("cat $tmp_output | cut -d ' ' -f 1");

    # Search for an event matching the given process ID
    assert_script_run("ausearch -p $pid > $tmp_output");

    # Extract event id from output log
    script_run("tail -1 $tmp_output > $tmp_backup");
    script_run("awk -F: '{print \$2}' $tmp_backup > $tmp_output");
    my $event_id = script_output("cat $tmp_output | cut -d ')' -f 1");

    # Search for an event based on the given event ID
    validate_script_output("ausearch --event $event_id", sub { m/$event_id/ });

    # On 15-SP3 and lower, there may not be messages that contain 'x86_64'
    if (!is_sle('<=15-SP3')) {
        # Search for events based on a specific CPU architecture
        validate_script_output("ausearch -i --arch x86_64", sub { m/arch=x86_64/ });
    }
}

1;
