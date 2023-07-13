# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Validates text of Beta Distribution message
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use scheduler 'get_test_suite_data';
use Test::Assert 'assert_matches';

sub run {
    my $expected_beta_text = get_test_suite_data()->{beta_text};
    my $actual_beta_text = $testapi::distri->get_ok_popup_controller()->get_text();
    assert_matches(qr/$expected_beta_text/, $actual_beta_text,
        "Beta Distribution message does not match the expected one.");
}

1;
