# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Keyboard Layout dialog in YaST Firstboot Configuration.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_firstboot_basetest';
use strict;
use warnings;
use scheduler 'get_test_suite_data';
use cfg_files_utils;

sub run {
    my $test_data = get_test_suite_data()->{keyboard_layout};
    my $keyboard_layout = $testapi::distri->get_firstboot_keyboard_layout();
    compare_settings({
            expected => $test_data,
            current => $keyboard_layout->collect_current_keyboard_layout_info(),
            suppress_info => 1});
    $keyboard_layout->proceed_with_current_configuration();
}

1;
