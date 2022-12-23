# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that first disk was selected for installation
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'consoletest';

use strict;
use warnings;
use testapi;

use scheduler qw(get_test_suite_data);
use utils qw(arrays_subset);

sub compare_disks {
    my %args = @_;
    my $expected = $args{expected};
    my $got = $args{got};

    my @dif = arrays_subset($expected, $got);
    if (scalar @dif > 0) {
        die "Unexpected disks for this scenario:\n" .
          "Expected: " . join(",", @{$expected}) . " Got: " . join(",", @{$got});
    }
}

sub run {
    select_console 'root-console';

    my @errors;
    my $test_data = get_test_suite_data();
    my @used_disks = @{$test_data->{guided_partitioning}->{disks}};
    my @unused_disks = @{$test_data->{unused_disks}};

    # list info about block devices
    my @lsblk_output = split(/\n/, script_output('lsblk -n'));
    # get list of disk names
    my @actual_disks = map { (split ' ', $_)[0] } grep { /disk/ } @lsblk_output;
    # compare disks found with expected
    compare_disks(expected => [@used_disks, @unused_disks], got => \@actual_disks);
    # check existing partitioning in first disk
    for my $disk (@used_disks) {
        push @errors, "Disk $disk was not used for partitioning."
          unless (grep { /$disk\d/ } @lsblk_output) > 0;
    }
    # Check for non-existing partitioning/mount points/swap in remaining disks
    for my $disk (@unused_disks) {
        push @errors, "Disk $disk was wrongly used during partitioning."
          if (grep { /$disk.*(\/|[SWAP])/ } @lsblk_output) > 0;
    }
    # Show all found errors
    die "Found errors:\n" . join("\n", @errors) if @errors;
}

1;
