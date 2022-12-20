# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'Netlink message validation' test case of ATSec test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#110218

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = shift;

    select_console 'root-console';

    # Compile
    assert_script_run('cd /usr/local/atsec/pentest/netlink');
    assert_script_run("make");

    my @cases = (
        {name => 'Valid netlink get route message', result => 'response', test_file => 'netlink_knocker', param => 1},
        {name => 'Valid netlink get route message with the specified message sized 1 smaller than the actual size', result => 'response', test_file => 'netlink_knocker', param => 2},
        {name => 'valid netlink get route message with successively decrease the specified size', result => 'no response', test_file => 'netlink_knocker', param => 3},
        {name => 'netlink get route message with 0 message size', result => 'no response', test_file => 'netlink_knocker', param => 4},
        {name => 'netlink get route message large', result => 'no response', test_file => 'netlink_knocker', param => 5},
        {name => 'netlink_crypto message larger than specified (125 byte payload)', result => 'no response', test_file => 'netlink_knocker2-largerMsgThanSpecified', param => 'NETLINK_CRYPTO'},
        {name => 'netlink_audit message larger than specified (125 byte payload)', result => 'response', test_file => 'netlink_knocker2-largerMsgThanSpecified', param => 'NETLINK_AUDIT'},
        {name => 'netlink_crypto message larger than specified (10000 byte payload)', result => 'no response', test_file => 'netlink_knocker2-largerMsgThanSpecified-10000', param => 'NETLINK_CRYPTO'},
        {name => 'netlink_audit message larger than specified (10000 byte payload)', result => 'response', test_file => 'netlink_knocker2-largerMsgThanSpecified-10000', param => 'NETLINK_AUDIT'},
    );

    my $test_module_result = 'ok';

    foreach my $case (@cases) {
        my $expected_result = $case->{result};
        my $test_name = $case->{name};
        my $pid = background_script_run("./$case->{test_file} $case->{param}");

        # Wait for 5 seconds to see if the test process exists
        sleep 5;

        # If test case is 'valid netlink get route message with successively decrease the specified size',
        # this test will take longer than others, so we wail for more time
        sleep 5 if ($test_name eq 'valid netlink get route message with successively decrease the specified size');

        my $result = 'ok';
        my $test_result = script_run("ps -p $pid") ? 'response' : 'no response';

        if ($test_result ne $expected_result) {
            $result = 'fail';
            $test_module_result = 'fail' if ($test_module_result eq 'ok');
        }
        record_info("$test_name", "The test result is $test_result\nThe expected result is $expected_result", result => $result);

        # Kill the process because kernel doesn't response
        assert_script_run("kill -15 $pid") if ($test_result eq 'no response');
    }
    $self->result($test_module_result);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
