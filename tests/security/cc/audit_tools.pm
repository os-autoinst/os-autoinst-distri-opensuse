# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'audit-tools' test case of 'audit-test' test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#94450, poo#106816

use Mojo::Base 'consoletest';
use testapi;
use utils;
use version_utils 'is_sle';
use audit_test qw(run_testcase compare_run_log rerun_fail_cases);

sub restore_auditd {
    # The suite ends on 'auditd_stop', which stops the daemon and registers no cleanup,
    # and the 'auditd_reload' that follows it does not bring it back up. Restart it so the
    # modules scheduled after this one do not run against a dead auditd.
    script_run('systemctl is-active --quiet auditd || systemctl start auditd');
}

sub run {
    my ($self) = shift;

    select_console 'root-console';

    # Run test case
    run_testcase('audit-tools', timeout => 1200);

    # Rerun randomly fail cases
    rerun_fail_cases();

    # Compare current test results with baseline
    my $result = compare_run_log('audit-tools');
    $self->result($result);

    if ($result == 'fail' && is_sle '>=15-SP4') {
        record_soft_failure("bsc#1209910");
        $self->result('ok');
    }
}

sub post_run_hook {
    my ($self) = @_;
    restore_auditd;
    $self->SUPER::post_run_hook;
}

sub post_fail_hook {
    my ($self) = @_;
    restore_auditd;
    $self->SUPER::post_fail_hook;
}

1;
