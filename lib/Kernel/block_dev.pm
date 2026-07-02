# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Utilities for block and storage device handling in kernel tests.
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kernel::block_dev;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;

our @EXPORT_OK = qw(
  is_block_device
  record_storage_info
  create_loop_backing_file
  attach_loop_device
);

=head2 is_block_device

 is_block_device(@devices);

Asserts that each device in the list exists as a block device. Dies if any
device is not found, allowing the test to fail if a block device is not detected
on the SUT.

=cut

sub is_block_device {
    my (@devices) = @_;
    for my $dev (@devices) {
        assert_script_run("test -b $dev",
            fail_message => "Block device $dev not found");
    }
}

=head2 record_storage_info

 record_storage_info();

Records block device layout into the openQA test log as a diagnostic snapshot.

=cut

sub record_storage_info {
    record_info('devices', script_output(
            'lsblk -p -o NAME,TYPE,SIZE,MODEL,SERIAL,TRAN,MOUNTPOINT',
            proceed_on_failure => 1));
    record_info('/dev disks',
        script_output('ls -l /dev/nvme* /dev/vd* /dev/sd*', proceed_on_failure => 1));
    record_info('by-id', script_output('ls -l /dev/disk/by-id', proceed_on_failure => 1));
}

=head2 create_loop_backing_file

 create_loop_backing_file($path, $size, %opts);

Creates a loop device backing file with proper Btrfs host handling.

Arguments:
  $path - Full path to the backing file (e.g., '/opt/xfstests/test_dev')
  $size - Size specification (e.g., '5G', '1024M')
  %opts - Optional parameters:
    timeout => timeout in seconds (default: 300)

This function creates an empty file, applies chattr +C to disable CoW and
compression on Btrfs hosts (no-op on other filesystems), then uses fallocate
to allocate the requested space.

The chattr +C flag must be set on an empty file before data is written to
prevent Btrfs host filesystem issues:
  - CoW disabled: prevents physical space explosion during overwrites
  - Compression disabled: ensures full physical space allocation
  - Safe for all test filesystems (xfs, btrfs, ext4, overlay, nfs)

Returns: nothing (dies on error via assert_script_run)

=cut

sub create_loop_backing_file {
    my ($path, $size, %opts) = @_;
    my $timeout = $opts{timeout} // 300;

    assert_script_run("touch $path");
    script_run("chattr +C $path 2>/dev/null || true");
    assert_script_run("fallocate -l $size $path", $timeout);
}

=head2 attach_loop_device

 attach_loop_device($backing_file, %opts);

Attaches a loop device to a backing file and returns the loop device path.

Arguments:
  $backing_file - Path to the backing file
  %opts - Optional parameters:
    loop_dev => specific loop device path (e.g., '/dev/loop100')
                If not provided, uses 'losetup -f' to find next free device
    timeout  => timeout in seconds (default: 300)

Returns: the loop device path (e.g., '/dev/loop0')

=cut

sub attach_loop_device {
    my ($backing_file, %opts) = @_;
    my $timeout = $opts{timeout} // 300;

    if ($opts{loop_dev}) {
        assert_script_run("losetup -P $opts{loop_dev} $backing_file", $timeout);
        return $opts{loop_dev};
    } else {
        assert_script_run("losetup -fP $backing_file", $timeout);
        my $output = script_output("losetup -j $backing_file");
        my ($loop_dev) = $output =~ /^([^:]+):/;
        die "Failed to parse loop device from: $output" unless $loop_dev;
        return $loop_dev;
    }
}

1;
