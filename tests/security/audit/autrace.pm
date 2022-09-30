# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-Later
#
# Summary: Verify the "autrace" utility traces individual processes in a fashion similar to strace.
#          The output of autrace is logged to the audit log.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#81772, tc#1768579

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub get_pid {
    # Call this fuction to extract pid from autrace output in command line
    my $tmp_output = '/tmp/out';
    my $tmp_backup = '/tmp/backup';
    script_run("tail -1 $tmp_output > $tmp_backup");
    script_run("awk -F\\' '{print \$2}' $tmp_backup > $tmp_output");
    my $pid = script_output("cat $tmp_output | cut -d ' ' -f 4");
    return ($pid);
}

sub run {
    my $audit_log = '/var/log/audit/audit.log';
    my $tmp_output = '/tmp/out';

    select_console 'root-console';

    if (is_sle("<=12-SP5")) {
        # on 12-SP5 and lower, the file may have incorrect permission thus causing the test to fail.
        script_run("chmod 600 $audit_log");
    }

    # Use autrace to trace an individual process, output will be logged to audit log
    my $ret = script_run('autrace /bin/ls /tmp');
    if ($ret) {
        record_info('autrace_output: ', 'autrace will report error here as expected');
    } else {
        record_info('Error: ', 'autrace should report error here', result => 'fail');
    }

    # Delete all existing rules
    assert_script_run('auditctl -D');

    # Clear original audit log
    assert_script_run("echo '' > $audit_log");

    # Trace process again and record the pid
    assert_script_run("autrace /bin/ls > $tmp_output");
    my $pid = get_pid();

    # Run ausearch with the pid
    assert_script_run("ausearch -i -p $pid");

    # Clear log again
    assert_script_run("echo '' > $audit_log");

    # Try resource usage mode and record the pid
    assert_script_run("autrace -r /bin/ls > $tmp_output");
    $pid = get_pid();

    # Query audit daemon logs by pid and generate audit reports about files
    assert_script_run("ausearch --start recent -p $pid --raw | aureport --file --summary");

    # Query audit daemon logs by pid and generate audit reports about hosts
    assert_script_run("ausearch --start recent -p $pid --raw | aureport --host --summary");
}

1;
