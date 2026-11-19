# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run EAL4 'ipsec ciphers' case
# Maintainer: QE Security <none@suse.de>
# Tags: poo#110980, poo#201363

use Mojo::Base 'consoletest';
use testapi;
use utils;
use lockapi;
use Data::Dumper;
use Utils::Architectures 'is_s390x';
use security::cc_ipsec;

sub run {
    my ($self) = @_;
    select_console 'root-console';

    assert_script_run('export SYSTEMD_PAGER=""');
    assert_script_run('cd /usr/local/eal4/ipsec/IPSEC_basic_eval');

    mutex_wait('READY_FOR_IPSEC_CIPHERS');

    # Each case starts charon and brings up a connection, the default timeout is too short
    my $timeout = is_s390x ? 600 : 180;

    # Test esp
    my $esp_output = script_output('bash test_basic_ipsec_eval_esp.bash', $timeout);

    # Test ike
    my $ike_output = script_output('bash test_basic_ipsec_eval_ike.bash', $timeout);

    mutex_create('IPSEC_CLIENT_DONE');

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

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    upload_ipsec_diagnostics();
}

1;
