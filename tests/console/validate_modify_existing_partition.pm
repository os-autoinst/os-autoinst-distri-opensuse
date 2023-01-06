# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Verify the partition modified in modify_existing_partition.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use scheduler 'get_test_suite_data';
use Test::Assert ':all';

sub run {
    my $test_data = get_test_suite_data();

    select_console "root-console";

    my @partitions = ();
    # Module is used to validate logical volumes too, so if no plain partitions
    if (ref $test_data->{disks} eq 'ARRAY') {
        foreach my $disk (@{$test_data->{disks}}) {
            push @partitions, @{$disk->{partitions}};
        }
    }
    if (ref $test_data->{volume_groups} eq 'ARRAY') {
        foreach my $vg (@{$test_data->{volume_groups}}) {
            push @partitions, @{$vg->{logical_volumes}};
        }
    }

    die "No test data provided to validate" unless @partitions;

    foreach my $part (@partitions) {
        record_info("Check $part->{name}", "Verify that the partition filesystem is $part->{formatting_options}->{filesystem}");

        my $actual_fstype;
        my $expected_fstype = $part->{formatting_options}->{filesystem};
        if ($expected_fstype eq "swap") {
            # We cannot use df for swap, it is not actually mounted. lsblk shows [SWAP] in output if swap is on, but we have to process it.
            $actual_fstype = lc(script_output("lsblk | grep $part->{name} | sed 's/.* //;s/[][]//g'"));
        }
        else {
            $actual_fstype = script_output("df -PT $part->{mounting_options}->{mount_point} | grep -v \"Filesystem\" | awk '{print \$2}'");
        }
        assert_matches(qr/$expected_fstype/, $actual_fstype,
            "$expected_fstype does not match with $actual_fstype");

        record_info("Check size", "Verify that the partition size is $part->{size}");
        my $partsize = script_output("lsblk | grep $part->{name} | awk '{print \$4}'");

        assert_equals($part->{size}, $partsize);
    }
}

1;
