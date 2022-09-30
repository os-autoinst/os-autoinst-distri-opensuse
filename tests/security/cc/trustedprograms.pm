# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'trustedprograms' test case of 'audit-test' test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#95908

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use audit_test qw(run_testcase compare_run_log);
use bootloader_setup qw(add_grub_cmdline_settings);
use power_action_utils "power_action";

sub run {
    my ($self) = shift;

    select_console 'root-console';

    # For database testcases
    zypper_call('in perl-Expect');

    # Workaround for testcase pam01.
    # This case will restart sshd service many times in short time,
    # in case the test fails, we need to do workaround.
    assert_script_run('sed -i \'/\[Unit\]/aStartLimitIntervalSec=0\' /usr/lib/systemd/system/sshd.service');
    assert_script_run('systemctl daemon-reload');

    # For the test case 'password is acceptable, but previously used' in pam01 ([37] database pam01).
    # When we set a password which has been used previously, the operation should fail.
    # By default, this system doesn't have this limitation, we should set common-password to support it.
    assert_script_run('pam-config -a --pwhistory --pwhistory-remember=3');

    # The tests ([8] screen_locking and [9] screen_manage) require these settings in grub file.
    add_grub_cmdline_settings('no-scroll fbcon=scrollback:0', update_grub => 1);
    power_action('reboot', textmode => 1);
    $self->wait_boot(textmode => 1);

    select_console 'root-console';

    run_testcase('trustedprograms', (make => 1, timeout => 1200));

    # Compare current test results with baseline
    my $result = compare_run_log('trustedprograms');

    # Upload log files in tests, e.g. pam01.log
    my $output = script_output('ls tests | grep .log');
    my @log_files = split(/\n/, $output);
    upload_logs("tests/$_") for @log_files;

    $self->result($result);
}

sub test_flags {
    return {no_rollback => 1};
}

1;
