# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: usb_nic
# Summary: Simple smoke test for testing USB drive connected to system
# Maintainer: LSG QE Kernel <kernel-qa@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my ($self) = @_;

    select_serial_terminal;

    record_info("INFO: usb-devices", script_output('usb-devices'));
    # Optional USB serial match check
    my $expected_usb = get_var('USB_SERIAL');
    if ($expected_usb) {
        my $usb_serials = script_output("usb-devices | grep SerialNumber", proceed_on_failure => 1);
        die "No USB device serials found" unless $usb_serials;

        my @serials = map { s/.*SerialNumber=//r } split /\n/, $usb_serials;
        my $matched = grep { $_ eq $expected_usb } @serials;

        die "Expected USB serial '$expected_usb' not found among: @serials" unless $matched;
        record_info("USB Serial", "Expected USB serial found: $expected_usb");
    }


    my $lun = script_output 'lsscsi -t -v | awk -F" " \'/usb/ {split($2,a,/[\/]/); print a[6]}\'';
    die "no usb storage device connected" if $lun eq "";

    my $device = "/dev/" . script_output "lsscsi -v | awk -F\"/\" \'/$lun/ {print \$3; exit}\'";

    # create filesystem, mountpoint and temporary file
    my $tmp = script_output 'mktemp -d';
    my $file = "$tmp/file";
    my $md5 = "$tmp/md5";
    my $mountpoint = "$tmp/mount";
    my $file_copy = "$mountpoint/file";

    assert_script_run "mkdir $mountpoint";
    assert_script_run "mkfs.btrfs -f $device";

    assert_script_run "mount -t btrfs $device $mountpoint";
    assert_script_run "dd if=/dev/urandom of=$file bs=1M count=16";
    assert_script_run "md5sum $file > $md5";
    assert_script_run "cp $file $file_copy";

    # unmount and flush slab and page cache
    assert_script_run "umount $mountpoint";
    assert_script_run "echo 3 > /proc/sys/vm/drop_caches";

    # remount and check md5sum
    assert_script_run "mount -t btrfs $device $mountpoint";
    assert_script_run "cd $mountpoint; md5sum -c $md5; cd /";

    # cleanup
    assert_script_run("umount $mountpoint");
    assert_script_run("rm -r $tmp");
}

sub test_flags {
    return {fatal => 0};
}

1;

=head1 Discussion

Simple smoke test for testing USB drive connected to system. This test performs
a basic functional verification of a USB mass storage device. It ensures that
the device is detected correctly, matches an expected serial number if provided,
and can be formatted, mounted, and used reliably for I/O operations.

=head1 Configuration

=head2 USB_SERIAL

SerialNumber for the expected USB device
