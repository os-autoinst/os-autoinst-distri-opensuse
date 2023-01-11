# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The test module goes through the Suggested Partitioning wizard,
# keeping all the default values but explicitly enables separate /home
# partition.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use parent 'y2_installbase';
use strict;
use warnings FATAL => 'all';

sub run {
    my $partitioner = $testapi::distri->get_partitioner();
    $partitioner->edit_proposal(has_separate_home => 1);
}

1;
