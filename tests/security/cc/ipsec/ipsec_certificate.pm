# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run CC 'ipsec certificate' case
# Maintainer: QE Security <none@suse.de>
# Tags: poo#110734, poo#201363

use Mojo::Base 'consoletest';
use testapi;
use utils;
use Utils::Architectures;
use lockapi;
use version_utils 'is_sle';
use mmapi qw(wait_for_children get_children);
use network_utils 'iface';
use security::cc_ipsec;

my $test_cases = {
    example => 'pass',
    wrong_DN => 'fail',
    ecdsa => 'pass',
    rsa768 => is_sle('15-SP6+') ? 'fail' : 'pass',
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

    assert_script_run('cd /usr/local/eal4/ipsec/certificates');

    my $role = get_var('HOSTNAME');
    my ($server_ip, $client_ip) = ipsec_peer_ips();
    my $children = get_children();
    my $child = (keys %$children)[0];

    foreach my $tmp_case_name (sort(keys %$test_cases)) {
        my $expected_result = $test_cases->{$tmp_case_name};
        my $case_name = $tmp_case_name;
        $case_name =~ s/_/-/g;

        if ($role eq 'server') {
            assert_script_run("sh prepare-ipsec-test.sh $case_name $server_ip $client_ip server");
            # 'ipsec restart' in the script returns before charon has loaded the connection
            wait_ipsec_conn($case_name);
            mutex_create("server_ready_$tmp_case_name");
            mutex_wait("client_done_$tmp_case_name", $child);
            next;
        }
        assert_script_run("sh prepare-ipsec-test.sh $case_name $client_ip $server_ip client");
        wait_ipsec_conn($case_name);
        mutex_wait("server_ready_$tmp_case_name");
        my $output = script_output("ipsec up $case_name", is_s390x ? 300 : 120);

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
                $record_message .= ', versions older than 15-SP6 accept 768 bit RSA keys' if $case_name eq 'rsa768';
                # When the ipsec up succeed, we need to check if the connection works
                my $ret = script_retry("ping -c 1 -W 2 $server_ip", retry => 10, delay => 10, die => 0);
                if (!defined($ret) || $ret != 0) {
                    $result = 'fail';
                    $record_message = "The $case_name test result is expected, but the connection does NOT work after retries";
                    $self->result('fail');
                }
            }
        }
        else {
            $result = 'fail';
            $record_message = "The $case_name test result is unknown, see the output";
            $self->result('fail');
        }

        record_info($record_message, $output, result => $result);
        mutex_create("client_done_$tmp_case_name");
    }
    wait_for_children() if ($role eq 'server');

    # Delete the ip that ipsec_server or ipsec_client added on s390x
    my $ip = $role eq 'server' ? $server_ip : $client_ip;
    assert_script_run("ip addr del $ip/24 dev " . iface) if is_s390x;
}

sub test_flags {
    # On the server, ipsec_gmac_check reads the journal of this boot after this
    # module, thus do not roll back to the last milestone on failure
    return {no_rollback => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    upload_ipsec_diagnostics();
}

1;
