# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'chrony pid file test' test case of EAL4 test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#111386

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use eal4_test;

sub run {
    my ($self) = shift;
    my $test_log_r = "chronyd_pid_file_log_r.txt";
    my $test_log_u = "chronyd_pid_file_log_u.txt";

    select_console 'root-console';
    script_run('printf "# Starting chrony_pid test #\n" >> ' . $test_log_r . '');

    # The chrony pid file does not exist is the expected result
    script_run('printf "# Check chronyd status: active is the expected result #\n" >> ' . $test_log_r . '');
    script_run('find /run -name "*chrony*" | grep \'\\.pid\' >> ' . $test_log_r . '');
    if (script_run('find / -name "*chrony*" | grep \'\\.pid\'') == 0) {
        record_info('There is chronyd pid file in system', script_output('systemctl status chronyd.service'), result => 'fail');
    }

    # Check chronyd status: inactive is the expected result
    script_run('printf "# Check chronyd status: inactive is the expected result\n" >> ' . $test_log_r . '');
    script_run('printf "systemctl status --no-pager chronyd.service\n" >> ' . $test_log_r . '');
    validate_script_output('systemctl status --no-pager chronyd.service', sub { m/Active: inactive/ }, proceed_on_failure => 1);

    # Start chronyd
    script_run('printf "# Start chronyd\n" >> ' . $test_log_r . '');
    script_run('printf "start chronyd.service\n" >> ' . $test_log_r . '');
    systemctl('start chronyd.service');

    # Check chronyd status: active is the expected result
    script_run('printf "# Check chronyd status: active is the expected result\n" >> ' . $test_log_r . '');
    script_run('printf "systemctl status --no-pager chronyd.service\n" >> ' . $test_log_r . '');
    validate_script_output('systemctl status --no-pager chronyd.service', sub { m/Active: active/ });
    script_run('systemctl status --no-pager chronyd.service >> ' . $test_log_r . '');

    script_run('printf "find /run -name "*chrony*" | grep \'\\.pid\'\n" >> ' . $test_log_r . '');
    validate_script_output('find /run -name "*chrony*" | grep \'\\.pid\'', sub { m/chronyd\.pid/ });
    script_run('find /run -name "*chrony*" | grep \'\\.pid\' >> ' . $test_log_r . '');
    upload_log_file($test_log_r);

    select_console 'user-console';
    script_run('printf "# Selected non root user\n" >> ' . $test_log_u . '');

    # Create a temp file for testing
    script_run('printf "# Create a temp file for testin\n" >> ' . $test_log_u . '');
    script_run('printf "touch test\n" >> chronyd_pid_file_log.txt');
    assert_script_run('touch test');

    # Create file and link in /run folder, expected result: fail
    script_run('printf "# Create file and link in /run folder, expected result: fail\n" >> ' . $test_log_u . '');
    script_run('printf "ln -s test /run/testlink 2>&1\n" >> ' . $test_log_u . '');
    validate_script_output('ln -s test /run/testlink 2>&1', sub { m/Permission denied/ }, proceed_on_failure => 1);
    script_run('ln -s test /run/testlink >> ' . $test_log_u . ' 2>&1');

    # Attempt to create a file in /run, expected result: fail
    script_run('printf "\n# Attempt to create a file in /run, expected result: fail\n" >> ' . $test_log_u . '');
    script_run('printf "touch /run/test 2>&1\n" >> ' . $test_log_u . '');
    validate_script_output('touch /run/test 2>&1', sub { m/Permission denied/ }, proceed_on_failure => 1);
    script_run('touch /run/test /run/testlink >> ' . $test_log_u . ' 2>&1');

    script_run('printf "\n# Ending chrony_pid test #\n" >> ' . $test_log_u . '');
    upload_log_file($test_log_u);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
