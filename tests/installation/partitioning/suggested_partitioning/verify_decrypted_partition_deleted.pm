# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The test module reuses the partition that was created with LVM on
# previous installation and verifies that the encrypted partition and the
# relevant mount points are marked for deletion in the partitioning list.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use parent 'y2_installbase';
use strict;
use warnings;
use Test::Assert qw(assert_matches);
use List::MoreUtils qw(pairwise);
use scheduler 'get_test_suite_data';

sub run {
    my $test_data = get_test_suite_data();
    my @expected_strings = @{$test_data->{partitioning_deletion_entries}};

    my $partitioner = $testapi::distri->get_suggested_partitioning();
    my $text = $partitioner->get_partitioning_changes_summary();
    my @deletion_entries = Mojo::DOM->new($text)->find('b')->map('text')->each;

    if (scalar @deletion_entries ne scalar @expected_strings) {
        die "Number of partitioning deletion entries do not match the provided test data.";
    }

    pairwise {
        assert_matches(qr/$a/, $b, "Expected entry /$a/ not found in suggested partitioner's deletion entry $b");
    } @expected_strings, @deletion_entries;
}

sub test_flags {
    return {fatal => 0};
}

1;
