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

sub run {
    select_console 'root-console';
    my $expected_install_hostname = is_zvm ? get_required_var('ZVM_GUEST')
      : is_s390x ? (split(/\./, get_required_var('SUT_IP')))[0]
      : get_test_suite_data()->{hostname} // 'localhost';
    my $hostname = script_output('hostnamectl hostname');
    assert_str_equals($expected_install_hostname, $hostname, "Wrong hostname. Expected: '$expected_install_hostname', got '$hostname'");
}

1;
