# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Accept proposed partitioning layout
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use parent 'y2_installbase';
use warnings FATAL => 'all';

sub run {
    $testapi::distri->get_suggested_partitioning()->get_suggested_partitioning_page();
    $testapi::distri->get_navigation()->proceed_next_screen();
}

1;
