# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Accept current timezone configuration
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use parent 'y2_installbase';
use strict;
use warnings;

sub run {
    $testapi::distri->get_clock_and_time_zone()->get_clock_and_time_zone_page();
    $testapi::distri->get_navigation()->proceed_next_screen();
}

1;
