# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Simple RAID partitioning layout validation
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use Utils::Architectures;
use version_utils 'is_sle';
use Test::Assert ':all';

#
# Define blocks of expected data for partitioning layout in different products and architectures
#
# 4 btrfs partitions mounted on / in raid partition, with new lsblk output, partition is listed only once
my $btrfs = qr/(md0(p1)?.+btrfs.+\/.*){4}|(md0(p1)?.+btrfs.+\/.*){1}/s;
# 4 swap partitions in raid partition, with new lsblk output partitions are listed only once
my $swap = qr/(md((1|2)p1)?.+swap.+\[SWAP\].*){4}|(md((1|2)p1)?.+swap.+\[SWAP\].*){1}/s;
# 8 raid partitions, with new lsblk output, with new lsblk output partitions are listed only once
my $raid_partitions_2_arrays = qr/(md(0|1).*){8}|(md(0|1).*){2}/s;
# 12 raid partitions, with new lsblk output partitions are listed only once
my $raid_partitions_3_arrays = qr/(md(0|1|2).*){12}|(md(0|1|2).*){3}/s;
# 8 linux raid members
my $linux_raid_member_2_arrays = qr/((v|s)d(a|b|c|d)(2|3).+linux_raid_member.*){8}/s;
# 12 linux raid members
my $linux_raid_member_3_arrays = qr/((v|s)d(a|b|c|d)(1|2|3|4).+linux_raid_member.*){12}/s;
# 4 hard disks
my $hard_disks = qr/((v|s)d(a|b|c|d)\D+.*){4}/s;
# 4 ext4 partitions mounted on /boot, with new lsblk output partitions are listed only once
my $ext4_boot = qr/(md1(p1)?.+ext4.+\/boot.*){4}|(md1(p1)?.+ext4.+\/boot.*){1}/s;
# Unique vfat partition in first disk (mounted on /boot/efi)
my $vfat_efi = qr/(vd(a|b|c|d))1.*vfat.*\/boot\/efi/s;
#
# Define blocks of expected data for raid configuration in different products and architectures
#
# RAID arrays
my @raid_arrays = qw(/dev/md0 /dev/md1);
# Number of array devices
my $num_raid_arrays = @raid_arrays;
# RAID level from settings
my $level = get_required_var('RAIDLEVEL');
# RAID array with corresponding RAID level
my $raid_level = qr/\/dev\/md0:.*?Raid Level : raid$level/s;
# RAID array always with level 0
my $raid0 = qr/\/dev\/md(1|2):.*?Raid Level : raid0/s;
# RAID array always with level 1? why?
my $raid1 = qr/\/dev\/md1:.*?Raid Level : raid1/s;
my @raid_detail = (
    # 4 RAID devices per RAID array
    /(Raid Devices : 4.*){$num_raid_arrays}/s,
    # 4 active RAID devices per RAID array
    /(Active Devices : 4.*){$num_raid_arrays}/s,
    # 4 working RAID devices per RAID array
    /(Working Devices : 4.*){$num_raid_arrays}/s,
    # 1st raid device per RAID array, i.e.: /dev/vda2
    /(0.*\/dev\/\w{2}a\d.*){$num_raid_arrays}/s,
    # 2nd raid device per RAID array, i.e.: /dev/vdb2
    /(1.*\/dev\/\w{2}b\d.*){$num_raid_arrays}/s,
    # 3rd raid device per RAID array, i.e.: /dev/vdc2
    /(2.*\/dev\/\w{2}c\d.*){$num_raid_arrays}/s,
    # 4th raid device per RAID array, i.e.: /dev/vdd2
    /(3.*\/dev\/\w{2}d\d.*){$num_raid_arrays}/s,
);
# Store test data to test expected partitioning/raid in specific architecture/product
my (
    @partitioning,
    @raid,
);
# Prepare test data depending on specific architecture/product
sub prepare_test_data {
    if (is_ppc64le || is_ppc64) {
        @partitioning = (
            $raid_partitions_3_arrays, $hard_disks, $linux_raid_member_3_arrays,
            $ext4_boot,
            $btrfs, $swap,
        );
        # Additional RAID array (update num_raid_arrays to regenerate regex)
        push(@raid_arrays, '/dev/md2');
        $num_raid_arrays = @raid_arrays;
        @raid = (($raid_level, $raid0, $raid1), @raid_detail);
    }
    elsif (is_aarch64) {
        @partitioning = @partitioning = (
            $raid_partitions_2_arrays, $hard_disks, $linux_raid_member_2_arrays,
            $vfat_efi,
            $btrfs, $swap,
        );
        @raid = (($raid_level, $raid0), @raid_detail);
    }
    elsif (is_x86_64 && is_sle('<15')) {
        @partitioning = (
            $btrfs, $ext4_boot, $swap,
            $hard_disks, $linux_raid_member_3_arrays,
        );
        # Additional RAID array (update num_raid_arrays to regenerate regex)
        push(@raid_arrays, '/dev/md2');
        $num_raid_arrays = @raid_arrays;
        @raid = (($raid_level, $raid0, $raid1), @raid_detail);
    }
    else {
        @partitioning = (
            $raid_partitions_2_arrays, $hard_disks, $linux_raid_member_2_arrays,
            $btrfs, $swap,
        );
        @raid = (($raid_level, $raid0), @raid_detail);
    }
}

sub command_output {
    my %args = @_;
    my $name = $args{name};
    my $options = $args{options};
    my $description = "$args{description}\n$name $options";
    my @expected = @{$args{matches}};
    record_info($name, $description);
    my $actual = script_output("$name $options");
    assert_matches($_, $actual, "Partition not found") for (@expected);
}

sub run {
    select_console 'root-console';
    prepare_test_data;
    command_output(
        name => 'lsblk',
        options => '--list --output NAME,FSTYPE,MOUNTPOINT',
        description => 'Verify partitioning',
        matches => \@partitioning,
    );
    command_output(
        name => 'mdadm',
        options => "--detail " . join(' ', @raid_arrays),
        description => 'Verify raid configuration',
        matches => \@raid,
    );
}

1;
