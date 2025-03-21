# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Validate the base product from /etc/products.d/*.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use Test::Assert ':assert';
use scheduler 'get_test_suite_data';

sub run {
    record_info("baseproduct", "Validate base product");
    select_console 'root-console';
    my $test_data = get_test_suite_data();
    my $expected_prod = $test_data->{os_release_name};
    my $prod = script_output 'basename `readlink /etc/products.d/baseproduct ` .prod';
    assert_equals($expected_prod, $prod, "Wrong product name in '/etc/products.d/baseproduct'");
}

1;
