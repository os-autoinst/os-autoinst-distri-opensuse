# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Accept current timezone configuration
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use parent 'y2_installbase';

sub run {
    $testapi::distri->get_clock_and_time_zone()->get_clock_and_time_zone_page();
    $testapi::distri->get_navigation()->proceed_next_screen();
}

1;
