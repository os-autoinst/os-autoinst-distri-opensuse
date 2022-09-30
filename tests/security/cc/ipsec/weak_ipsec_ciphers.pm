# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run ATSec 'Weak IPsec ciphers' case
# Maintainer: QE Security <none@suse.de>
# Tags: poo#101226

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use lockapi;

sub run {
    my ($self) = @_;
    select_console 'root-console';

    assert_script_run('cd /usr/local/atsec/ipsec/IPSEC_basic_eval');
    my $output = script_output('bash test_basic_ipsec_eval_weak.bash');

    my @lines = split(/\n/, $output);
    foreach my $line (@lines) {
        if ($line =~ (/(.*):\s+(.*)/)) {
            # This is used to test weak ciphers are not allowed.
            # If the connection are establish, it means test failed
            # because the ciphers written in ipsec.conf are not allowed.
            my $result = $2 eq 'Okay' ? 'fail' : 'ok';
            record_info($1, "Case $1 result is $2", result => $result);
            $self->result($result) if $result eq 'fail';
        }
    }

    mutex_create('WEAK_IPSEC_CIPHERS_DONE');

    # Parse the log file to check if the failure reason is expected
    my $log_file = 'ccc-ipsec-eval-weak.log';
    my $contents = script_output("cat $log_file");

    my $test_results = {};
    my @test_cases;
    my ($test_name, $fail_reason);
    foreach my $c (split(/\n/, $contents)) {
        if ($c =~ /(IKE version:.*|esp:.*)/) {
            $test_name = $1;
            $fail_reason = undef;
            push(@test_cases, $test_name);
        }
        elsif ($c =~ /NO_PROPOSAL_CHOSEN/) {
            $test_results->{$test_name} = $c;
            $test_name = undef;
        }
    }
    foreach my $case (@test_cases) {
        if (my $reason = $test_results->{$case}) {
            record_info($case, "Test case $case failed as expected: $reason");
        }
        else {
            record_info($case, "Test case $case failed in unexpected reason. See ccc-ipsec-eval-weak.log for details", result => 'fail');
            $self->result('fail');
        }
    }

    # Upload log file
    upload_logs($log_file);
}

1;
