# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Welcome dialog in YaST Firstboot Configuration.
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_firstboot_basetest';
use scheduler 'get_test_suite_data';

sub run {
    my $test_data = get_test_suite_data()->{welcome};
    my $welcome = $testapi::distri->get_firstboot_welcome();
    my $current_welcome_info = $welcome->collect_current_welcome_info();
    for my $line (@{$test_data->{text}}) {
        if ($current_welcome_info !~ $line) {
            die "Welcome message does not contain expected text '$line'";
        }
    }
    $welcome->proceed_with_current_configuration();
}

1;
