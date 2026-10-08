# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that the hostname is set properly by Agama.
# Check hostname against test data or default value from DHCP "localhost"

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use scheduler 'get_test_suite_data';
use Test::Assert ':assert';
use Utils::Architectures qw(is_s390x is_zvm);
use Utils::Backends qw(is_svirt);

sub run {
    select_console 'root-console';

    my $expected_install_hostname;
    if (my $hostname = get_test_suite_data()->{hostname}) {
        $expected_install_hostname = $hostname;
    } elsif (is_s390x) {
        my @s390x_resolvers = (
            {
                match => sub { is_zvm },
                resolve => sub { get_required_var('ZVM_GUEST') },
            },
            {
                match => sub { is_svirt },
                resolve => sub { (split(/\./, get_required_var('SUT_IP')))[0] },
            },
        );
        my ($active_rule) = grep { $_->{match}->() } @s390x_resolvers
          or die "Unable to determine expected install hostname for s390x: neither zVM nor sVirt matched";
        $expected_install_hostname = $active_rule->{resolve}->();
    } else {
        $expected_install_hostname = 'localhost';
    }

    my $hostname = script_output('hostnamectl hostname');
    assert_str_equals($expected_install_hostname, $hostname, "Wrong hostname. Expected: '$expected_install_hostname', got '$hostname'");
}

1;
