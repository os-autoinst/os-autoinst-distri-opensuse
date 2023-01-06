# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Finish Setup dialog in YaST Firstboot Configuration
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_firstboot_basetest';
use strict;
use warnings;
use scheduler 'get_test_suite_data';

sub run {
    my $test_data = get_test_suite_data()->{finish_setup};
    my $conf_completed = $testapi::distri->get_firstboot_configuration_completed();
    my $current_finish_setup = $conf_completed->collect_current_configuration_completed_info();
    for my $line (@{$test_data->{text}}) {
        if ($current_finish_setup->{text} !~ $line) {
            die "Finish setup message does not contain expected text '$line'";
        }
    }
    $conf_completed->proceed_with_current_configuration();
}

1;
