# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Accept proposed partitioning layout
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use parent 'y2_installbase';
use strict;
use warnings FATAL => 'all';

sub run {
    $testapi::distri->get_suggested_partitioning()->get_suggested_partitioning_page();
    $testapi::distri->get_navigation()->proceed_next_screen();
}

1;
