# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Validates text of Beta Distribution message
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';
use scheduler 'get_test_suite_data';
use Test::Assert 'assert_matches';

sub run {
    my $expected_beta_text = get_test_suite_data()->{beta_text};
    my $actual_beta_text = $testapi::distri->get_ok_popup()->get_text();
    assert_matches(qr/$expected_beta_text/, $actual_beta_text,
        "Beta Distribution message does not match the expected one.");
}

1;
