# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: cdrkit-cdrtools-compat udisks2 util-linux mkisofs
# Summary: Simple tests for udisks2 using udisksctl checking status,
# block device information and loop-setup.
# Maintainer: Michael Grifalconi <mgrifalconi@suse.com>

use strict;
use warnings;
use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle);

sub run {
    my $self = shift;
    select_serial_terminal;

    # Install udisks2 package. mkisofs and util-linux for support packages
    if (is_sle('<15')) {
        # mkisofs is part of 'cdrkit-cdrtools-compat' on SLE version older than 15
        zypper_call('in cdrkit-cdrtools-compat udisks2 util-linux');
    }
    else {
        zypper_call('in mkisofs udisks2 util-linux');
    }

    # Compares block devices from lsblk and udisksctl outputs.
    my $lsblk_output = script_output("lsblk");
    my $udiskctl_status_output = script_output("udisksctl status");
    my $current_test_device;
    my @tested_devices;
    for my $line (split /\n/, $lsblk_output) {
        if ($line =~ /^([a-z]d[a-z])(.*)disk/) {
            $current_test_device = $1;
            for my $udiskline (split /\n/, $udiskctl_status_output) {
                if ($udiskline =~ /^(.*)$current_test_device/) {
                    push @tested_devices, $current_test_device;

                    # Check if udisks2 output is valid (contains a sections for Block and Partition Table/or available).
                    validate_script_output("udisksctl info --block-device /dev/$current_test_device|tee", sub { m/UDisks2.*Block.*(HintPartitionable:\s+true|PartitionTable).*/s });
                }
            }
        }
    }

    die "Could not find a valid block device to test" unless (@tested_devices);
    print $_, "\n" for @tested_devices;


    # create iso file and map it by loop-setup
    assert_script_run "mkdir -p udisk_test";
    assert_script_run "dd if=/dev/zero of=udisk_test/testfile.data bs=512 count=10";
    assert_script_run "ls -l udisk_test/testfile.data";
    assert_script_run "mkisofs -o udisk_test.iso udisk_test/";
    my $udloop_output = script_output("udisksctl loop-setup -r -f udisk_test.iso 2>&1", proceed_on_failure => 1);

    if ($udloop_output =~ "Mapped") {
        assert_script_run "losetup -j /root/udisk_test.iso | grep loop";
    } else {
        die "Missing mapping info. Expected: Mapped value \nGot: /$udloop_output/";
    }

    # Gets device path from udisks loop-setup output
    my $device_path;
    for my $line (split /\n/, $udloop_output) {
        if ($line =~ /Mapped file\s+(.*?)\s+as\s(.*?)\./) {
            $device_path = $2;
        }
        # related to boo#1177419
        if ($line =~ /Error\swaiting\sfor\sloop\sobject.*'(.*)':/) {
            $device_path = $1;
        }
    }

    assert_script_run("udisksctl loop-delete -b $device_path");

    # clean
    assert_script_run "rm -rf udisk_test/";
    assert_script_run "rm -f udisk_test.iso";
}

1;
