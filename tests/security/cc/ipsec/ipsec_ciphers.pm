# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run ATSec 'ipsec ciphers' case
# Maintainer: QE Security <none@suse.de>
# Tags: poo#110980

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use lockapi;
use Data::Dumper;

sub run {
    my ($self) = @_;
    select_console 'root-console';

    assert_script_run('export SYSTEMD_PAGER=""');
    assert_script_run('cd /usr/local/atsec/ipsec/IPSEC_basic_eval');

    mutex_wait('READY_FOR_IPSEC_CIPHERS');

    # Test esp
    my $esp_output = script_output('bash test_basic_ipsec_eval_esp.bash');

    # Test ike
    my $ike_output = script_output('bash test_basic_ipsec_eval_ike.bash');

    mutex_create('IPSEC_CLEINT_DONE');

    my @results = (split(/\n/, "$esp_output\n$ike_output"));
    my $expect_failures = {
        'aes192-aes192gmac-modp2048!' => 1,
        'prfsha1-aes256-aes192gmac-modp2048!' => 1
    };

    my @known_fail_case;

    foreach my $line (@results) {

        # The output of test script such as:
        # ESP: aes128-sha512-modp2048! - Okay
        # ESP: aes192-aes192gmac-modp2048! - Error 1
        if ($line =~ /^(ESP:|IKE:)\s+(\S+)\s+-\s+(.*)/) {
            my $case = $2;
            my $result = $3;
            diag "Test case $case result is $result";
            if ($result eq 'Okay') {
                record_info($case, "$line");
                next;
            }
            if ($expect_failures->{$case}) {
                push @known_fail_case, $case;
                next;
            }
            record_info($case, "$line", result => 'fail');
            $self->result('fail');
        }
    }

    my $count_known_failures = @known_fail_case;
    diag(Dumper(\@known_fail_case));

    if ($count_known_failures > 0) {

        # Analyse the journal log to check if the failures are expected
        my $num = script_output('journalctl -b | grep "classic and combined-mode (AEAD) encryption algorithms can\'t be contained in the same ESP proposal"| wc -l');
        if ($num == $count_known_failures) {
            record_info($_, "$_ failed as expected") for @known_fail_case;
        }
        else {
            record_info($_, "$_ failed as unexpected, need some analysis", result => 'fail') for @known_fail_case;
            $self->result('fail');
        }
    }
    # Upload log files
    upload_logs('ccc-ipsec-eval-esp.log');
    upload_logs('ccc-ipsec-eval-ike.log');
}

1;
