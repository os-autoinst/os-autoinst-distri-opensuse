# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'netfilter' and 'netfilebt' test cases of 'audit-test' test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#96540, poo#97271

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use audit_test qw(compare_run_log upload_audit_test_logs);

sub run {
    my ($self, $run_args) = @_;
    die 'Need case_name to know which test to run' unless $run_args && $run_args->{case_name};
    my $case_name = $run_args->{case_name};
    my $result = 'ok';
    assert_script_run("cd $audit_test::test_dir/audit-test/$case_name/");
    my $output = script_output('./run.bash --list');
    my @lines = split(/\n/, $output);

    # Start lblnet_tst_server
    my $lblnet_cmd = "$audit_test::test_dir/audit-test/utils/network-server/lblnet_tst_server";
    my $pid = script_output('ps -C lblnet_tst_server -o pid=');

    # This function is used to run netfilter and netfilebt cases.
    # When one case finishes, the port maybe hasn't been released, so we need to restart
    # `lblnet_tst_server` in case the following test case ends with ERROR.
    # So the test cases in netfilter will be run one by one.
    my @test_lists;
    foreach (@lines) {
        my $num;
        if ($_ =~ /\[(\d+)\]\s+\S+/) {
            $num = $1;
        } else {
            next;
        }
        my $cmd = "./run.bash $num";
        my $result = script_output($cmd, timeout => 600);

        # If the port is busy, the test case will end with error, we need to restart lblnet_tst_server
        if (index($result, 'could not setup remote test server') != -1) {
            script_run("kill -9 $pid");
            $pid = background_script_run($lblnet_cmd);
            # Give more seconds for killing this process
            sleep 3;
            assert_script_run($cmd, timeout => 600);
        }
    }

    # The 8th test case in netfilter sometimes may end with ERROR because of the performance issue. we need to run it again
    assert_script_run('./run.bash 8', timeout => 300) if ($case_name eq 'netfilter' && script_run('egrep "[8].*ERROR" rollup.log') == 0);
    # Upload logs
    upload_audit_test_logs($case_name);
    # Compare current test results with baseline
    $result = compare_run_log($case_name);

    $self->result($result);
}

1;
