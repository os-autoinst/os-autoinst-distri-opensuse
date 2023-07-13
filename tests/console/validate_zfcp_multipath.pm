# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test module to validate zfcp multipath on z/VM testing infrastructure.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use Test::Assert ':all';

# Verify that there are two Host Bus adapters Attached (HBA), and that the corresponding channels are listed
sub verify_host_bus_adapters_attached {
    my @expected_channels = @_;
    my $actual_channels = script_output "ls -ld /sys/class/fc_host/*";
    # number of lines in the output should be equal to number of channels
    assert_equals scalar(@expected_channels), scalar(split /\n/, $actual_channels), "Invalid number of channels";
    for my $expected (@expected_channels) {
        assert_matches qr/$expected/, $actual_channels, "Channel not found: $expected";
    }
}

# Verify that there are 8 SCSI block devices listed (as a result of having two adapters, two hard disks and two paths to each disk, 2^3 = 8)
# Verify that LUN 0x4001403200000000 corresponds to the 214GB disk, and LUN 0x4001405000000000 to the 42.9GB disk
sub verify_plain_scsi_block_devices {
    my @all_scsi_list = split /\n/, script_output "lsscsi -xxgst";
    my $large_disks = scalar grep { /0x4001403200000000.+214GB/ } @all_scsi_list;
    my $small_disks = scalar grep { /0x4001405000000000.+42.9GB/ } @all_scsi_list;
    assert_equals 4, $large_disks, "Expected 4 SCSI block devices sized 214GB at LUN 0x4001403200000000 found $large_disks";
    assert_equals 4, $small_disks, "Expected 4 SCSI block devices sized 42.9GB at LUN 0x4001405000000000, found $small_disks";
}

# Verify that the multipath device with WWID 36005076307ffd3b30000000000000132 corresponds to the 200G disk and the multipath device with WWID 36005076307ffd3b30000000000000150 to the 40G disk
# Verify that there are 4 block devices listed for each virtual multipath device, and those corresponds to the right LUN (1077035009 and 1079001089)
sub verify_multipath_block_devices {
    my $mpath = script_output "multipath -l";
    my @mpath = split /\n/, $mpath;
    # check for 200GB disk (multiline match)
    assert_matches qr/^36005076307ffd3b30000000000000132.+\n^size=200G/m, $mpath, "Cannot find 200GB disk on WWID *132";
    # must see the LUN 1077035009 over 4 paths
    my $large_disks = scalar grep { /1077035009/ } @mpath;
    assert_equals 4, $large_disks, "200GB block device does not have 4 paths";
    # check for 40GB disk (multiline match)
    assert_matches qr/^36005076307ffd3b30000000000000150.+\n^size=40G/m, $mpath, "Cannot find 40GB disk on WWID *150";
    # must see the LUN 1079001089 over 4 paths
    my $small_disks = scalar grep { /1079001089/ } @mpath;
    assert_equals 4, $small_disks, "40GB block device does not have 4 paths";
}

sub run {
    select_console 'root-console';
    verify_host_bus_adapters_attached("0.0.fa00", "0.0.fc00");
    verify_plain_scsi_block_devices;
    verify_multipath_block_devices;
}

1;
