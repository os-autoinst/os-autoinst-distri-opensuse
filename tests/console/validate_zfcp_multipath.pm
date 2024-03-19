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

# Verify that there are 2 SCSI block devices listed
# Verify that LUN 0x0000000000000000 corresponds to 53.6GB disk
sub verify_plain_scsi_block_devices {
    my @all_scsi_list = split /\n/, script_output "lsscsi -xxgst";
    my $disks = scalar grep { /0x0000000000000000.+53\.6GB/ } @all_scsi_list;
    assert_equals 2, $disks, "Expected 2 SCSI block devices sized 53.6GB at LUN 0x0000000000000000 found $disks";
}

# Verify that the multipath device with dynamic WWID corresponds to the 50G disk
# Verify that there are 2 block devices listed for each virtual multipath device
sub verify_multipath_block_devices {
    my $mpath = script_output "multipath -l";
    my @mpath = split /\n/, $mpath;
    my $wwid_first_disk = script_output "/usr/lib/udev/scsi_id --whitelisted --replace-whitespace --device=/dev/sda";
    # check for 50GB disk (multiline match)
    assert_matches qr/^$wwid_first_disk.+\n^size=50G/m, $mpath, "Cannot find 50GB disk on WWID *076";
    # must see the LUN over 2 paths
    my $disks = scalar grep { /\bsd(a|b)\b/ } @mpath;
    assert_equals 2, $disks, "50GB block device does not have 2 paths";
}

sub run {
    select_console 'root-console';
    verify_host_bus_adapters_attached("0.0.fa00", "0.0.fc00");
    verify_plain_scsi_block_devices;
    verify_multipath_block_devices;
}

1;
