# SUSE's openQA tests
#
# Copyright � 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Validate that first disk was selected for installation
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'consoletest';

use strict;
use warnings;
use testapi;

use scheduler qw(get_test_suite_data);
use utils qw(arrays_subset);

sub compare_disks {
    my %args     = @_;
    my $expected = $args{expected};
    my $got      = $args{got};

    my @dif = arrays_subset($expected, $got);
    if (scalar @dif > 0) {
        die "Unexpected disks for this scenario:\n" .
          "Expected: " . join(",", @{$expected}) . " Got: " . join(",", @{$got});
    }
}

sub run {
    select_console 'root-console';

    my @errors;
    my @expected_disks = @{get_test_suite_data()->{disks}};

    # list info about block devices
    my @lsblk_output = split(/\n/, script_output('lsblk -n'));
    # get list of disk names
    my @disks = map { (split ' ', $_)[0] } grep { /disk/ } @lsblk_output;
    # compare disks found with expected
    compare_disks(expected => \@expected_disks, got => \@disks);
    # get first disk names
    my $first_disk = shift @expected_disks;
    # check existing partitioning in first disk
    push @errors, "First disk $first_disk was not used for partitioning."
      unless (grep { /$first_disk\d/ } @lsblk_output) > 0;
    # Check for non-existing partitioning/mount points/swap in remaining disks
    for my $disk (@expected_disks) {
        push @errors, "Disk $disk was wrongly used during partitioning."
          if (grep { /$disk.*(\/|[SWAP])/ } @lsblk_output) > 0;
    }
    # Show all found errors
    die "Found errors:\n" . join("\n", @errors) if @errors;
}

1;
