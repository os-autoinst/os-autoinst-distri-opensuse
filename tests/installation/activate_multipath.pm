# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Activates multipath when multipath activation message appears
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use parent 'y2_installbase';
use strict;
use warnings;
use Test::Assert 'assert_matches';
use scheduler 'get_test_suite_data';

sub run {
    my $expected_text = get_test_suite_data()->{multipath_activation_message};
    my $popup_controller = $testapi::distri->get_yes_no_popup_controller();
    my $actual_text = $popup_controller->get_text();
    assert_matches(qr/$expected_text/, $actual_text, "Unexpected text message when activating multipath");
    $popup_controller->accept();
}

1;
