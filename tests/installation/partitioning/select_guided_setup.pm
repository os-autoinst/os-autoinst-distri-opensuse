# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary:
#
# Summary: This test module selects the guided setup
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use parent 'y2_installbase';
use warnings FATAL => 'all';
use testapi;

sub run {
    my $suggested_partitioning = $testapi::distri->get_suggested_partitioning();
    $suggested_partitioning->select_guided_setup();
}

1;
