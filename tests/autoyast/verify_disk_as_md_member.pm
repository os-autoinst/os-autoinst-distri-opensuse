# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: util-linux
# Summary: Validate partitioning for autoyast installation when using disks as
#          Multiple Device member. Uses two devices.
#          The test verifies that the following configuration of the installed
#          system match the parameters in autoyast profile:
#             1. Number of partitions on MD RAID;
#             2. RAID level;
#             3. Mount points for MD partitions.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use testapi;
use base 'basetest';
use scheduler 'get_test_suite_data';
use Test::Assert ':all';

sub collect_disk_data {
    my ($disk) = @_;
    return script_output("lsblk $disk -l --noheading --output NAME,TYPE,MOUNTPOINT");
}

sub run {
    my $test_data = get_test_suite_data();
    my $disk_data = collect_disk_data($test_data->{disk});

    my @partitions = ($disk_data =~ /$test_data->{type_part}/g);

    record_info('Partitions count', 'Verify that MD RAID contains correct number of partitions.');
    assert_equals($test_data->{partitions_count}, scalar @partitions, 'MD RAID contains wrong number of partitions.');

    record_info('RAID level', 'Verify that RAID level on the installed system corresponds to the expected one.');
    assert_true($disk_data =~ m/$test_data->{raid_level}/, 'Wrong raid level is shown for the MD.');

    record_info('Mount points', 'Verify that MD contains all the expected mount points.');
    assert_true($disk_data =~ m/$test_data->{mount_point}->{root}/,
        "\"$test_data->{mount_point}->{root}\" mount point is not found among MD RAID partitions.");
    assert_true($disk_data =~ m/$test_data->{mount_point}->{data}/,
        "\"$test_data->{mount_point}->{data}\" mount point is not found among MD RAID partitions.");
}

1;
