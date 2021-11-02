# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'kvm_svirt_apparmor' test case of 'audit-test' test suite
# Maintainer: Liu Xiaojing <xiaojing.liu@suse.com>
# Tags: poo#101761

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use Mojo::File 'path';
use audit_test 'prepare_for_test';

sub run {
    my ($self) = shift;

    select_console 'root-console';

    # The steps of testing kvm_svirt_apparmor is not same as other audit-test,
    # so we need to do the `make` in the test case directory and run the test.
    prepare_for_test();

    assert_script_run('cd kvm_svirt_apparmor/');

    # prepare_for test did the `export MODE=64`, that will make this make fail in aarch64
    script_run('unset MODE');
    assert_script_run('make');
    assert_script_run('cd tests/');
    assert_script_run('./vm-sep');

    # There is no baseline file, so we need to check the test result by parse log file
    # in /tmp/vm-sep/vm-sep-crack.log
    my $log_file = '/tmp/vm-sep/vm-sep-crack.log';
    assert_script_run("[[ -e $log_file ]]");
    my $test_results = {};
    my $output = script_output("cat $log_file");
    my @lines = split(/\n/, $output);
    foreach (@lines) {
        if ($_ =~ /Number of tests (executed|failed|passed):\s+(\d+)/) {
            $test_results->{$1} = $2;
        }
    }
    $self->result('fail') if ($test_results->{passed} ne $test_results->{executed});

    upload_logs($log_file);
}

1;
