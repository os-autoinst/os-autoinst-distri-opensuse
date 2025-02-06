# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles validation in the system installed by Agama.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use Test::Assert ':all';
use scheduler 'get_test_suite_data';

sub validate_base_product {
    record_info("baseproduct", "Validate base product");
    select_console 'root-console';
    my $prod = script_output 'basename `readlink /etc/products.d/baseproduct ` .prod';
    assert_equals(shift, $prod, "Wrong product name in '/etc/products.d/baseproduct");
}

sub validate_first_user {
    record_info("1st user", "Validate first user");
    select_console 'user-console';
}

sub run {
    my $test_data = get_test_suite_data();
    my @validations = split(',', get_required_var("AGAMA_VALIDATE"));
    my %dispatch_table = (
        base_product => \&validate_base_product,
        first_user => \&validate_first_user
    );

    foreach my $validation (@validations) {
        die "key '$validation' not defined in test data\n" unless (exists $test_data->{$validation});
        die "function for key '$validation' not defined in dispatch table table\n" unless (exists $dispatch_table{$validation});
        my $function_ref = $dispatch_table{$validation};
        &$function_ref($test_data->{$validation});
    }
}

1;
