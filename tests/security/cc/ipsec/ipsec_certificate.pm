# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run CC 'ipsec certificate' case
# Maintainer: QE Security <none@suse.de>
# Tags: poo#110734

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use atsec_test;
use Utils::Architectures;
use lockapi;
use mmapi qw(wait_for_children get_children);

my $test_cases = {
    example => 'pass',
    wrong_DN => 'fail',
    ecdsa => 'pass',
    rsa768 => 'pass',
    self_signed => 'fail',
    expired => 'fail',
    wrong_signature => 'fail',
    revoked => 'fail',
    missing_basic_constraints => 'fail',
    invalid_ASN1 => 'fail'
};

sub run {
    my ($self) = @_;
    select_console 'root-console';

    assert_script_run('cd /usr/local/atsec/ipsec/certificates');

    my $role = get_var('HOSTNAME');
    my $children = get_children();
    my $child = (keys %$children)[0];

    foreach my $tmp_case_name (sort(keys %$test_cases)) {
        my $expected_result = $test_cases->{$tmp_case_name};
        my $case_name = $tmp_case_name;
        $case_name =~ s/_/-/g;

        if ($role eq 'server') {
            assert_script_run("sh prepare-ipsec-test.sh $case_name $atsec_test::server_ip $atsec_test::client_ip server");
            mutex_create("server_ready_$tmp_case_name");
            mutex_wait("client_done_$tmp_case_name", $child);
            next;
        }
        assert_script_run("sh prepare-ipsec-test.sh $case_name $atsec_test::client_ip $atsec_test::server_ip client");
        mutex_wait("server_ready_$tmp_case_name");
        my $output = script_output("ipsec up $case_name", 120);

        my $result = 'ok';
        my $record_message = "The $case_name test result is expected";
        if ($output =~ /establishing connection '$case_name' failed/) {
            if ($expected_result ne 'fail') {
                $result = 'fail';
                $record_message = "The $case_name test result is NOT expected";
                $self->result('fail');
            }
        }
        elsif ($output =~ /connection '$case_name' established successfully/) {
            if ($expected_result ne 'pass') {
                $result = 'fail';
                $record_message = "The $case_name test result is NOT expected";
                $self->result('fail');
            }
            else {
                if ($case_name eq 'rsa768') {
                    $result = 'softfail';
                    $record_message = "$case_name pass, as ATSec document says, it needs more analysis";

                }
                # When the ipsec up succeed, we need to check if the connection is created
                my $ping_ret = script_run("ping -c 1 -W 2 $atsec_test::server_ip");
                if ($ping_ret != 0) {
                    $result = 'fail';
                    $record_message = "The $case_name test result is expected, but the connection does NOT work";
                    $self->result('fail');
                }
            }
        }
        else {
            $result = 'fail';
            $record_message = "$case_name test result needs some analysis";
        }

        record_info($record_message, $output, result => $result);
        mutex_create("client_done_$tmp_case_name");
    }
    wait_for_children() if ($role eq 'server');

    my $netdev = get_var('NETDEV', 'eth0');
    my $ip = $role eq 'server' ? $atsec_test::server_ip : $atsec_test::client_ip;

    # Delete the ip that we added if arch is s390x
    assert_script_run("ip addr del $ip/24 dev $netdev") if (is_s390x);
}

1;
