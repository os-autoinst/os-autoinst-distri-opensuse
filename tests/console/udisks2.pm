# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Simple tests from udisks2 using udisksctl checking status,
# block device information and loop-setup.
# Maintainer: João Walter Bruno Filho <bfilho@suse.com>

use strict;
use warnings;
use base 'consoletest';
use testapi;
use utils;

sub run {
    select_console 'root-console';

    # install udisks2 package. mkisofs and util-linux for support packages
    zypper_call('in mkisofs udisks2 util-linux');

    # Compares block devices from lsblk and udisksctl outputs.
    my $lsblk_output           = script_output("lsblk");
    my $udiskctl_status_output = script_output("udisksctl status");
    my $current_test_device;
    my @tested_devices;
    for my $line (split /\n/, $lsblk_output) {
        if ($line =~ /^([a-z]d[a-z])(.*)disk/) {
            $current_test_device = $1;
            for my $udiskline (split /\n/, $udiskctl_status_output) {
                if ($udiskline =~ /^(.*)$current_test_device/) {
                    push @tested_devices, $current_test_device;
                    # Check if Udisks2 output is valid (contains a sections for Block and Partition Table/or available).
                    validate_script_output("udisksctl info --block-device /dev/$current_test_device", sub { m/UDisks2.*Block.*[PartitionTable|HintPartitionable:\s+true]/s });
                }
            }
        }
    }

    die "Could not find a valid block device to test" unless (@tested_devices);
    print $_, "\n" for @tested_devices;


    # create iso file and map it by loop-setup
    assert_script_run "mkdir -p udisk_test";
    assert_script_run "dd if=/dev/zero of=udisk_test/testfile.data bs=512 count=10";
    assert_script_run "ls -ld udisk_test/testfile.data";
    assert_script_run "mkisofs -o udisk_test.iso udisk_test/";
    my $udloop_output = script_output("udisksctl loop-setup -r -f udisk_test.iso");

    die "Missing exiv2 info. Expected: Mapped value \nGot: /$udloop_output/"
      unless $udloop_output =~ "Mapped";

    # Gets device path from udisks loop-setup output
    my $device_path;
    for my $line (split /\n/, $udloop_output) {
        if ($line =~ /Mapped file\s+(.*?)\s+as\s(.*?)\./) {
            $device_path = $2;
        }
    }

    my $loop_dev =
      # my loop_value script_output("udisksctl loop-setup -r -f openSUSE-Leap-15.0-NET-x86_64.iso", sub { m/Mapped/s });
      assert_script_run("udisksctl loop-delete -b $device_path");

    # clean
    assert_script_run "rm udisk_test/ -rf";
    assert_script_run "rm udisk_test.iso";
}

1;
