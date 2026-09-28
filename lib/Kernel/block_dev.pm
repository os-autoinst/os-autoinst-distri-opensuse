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
  create_zoned_nullblk
  start_block_trace
  stop_block_trace
  count_block_writes
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

=head2 create_zoned_nullblk

 create_zoned_nullblk(%opts);

Creates a zoned null_blk device via configfs.

Arguments:
  %opts - Optional parameters:
    blocksize     => block size in bytes (default: 4096)
    zone_size     => zone size in MB (default: 256)
    zone_nr_conv  => number of conventional zones (default: 4)
    zone_nr_seq   => number of sequential zones (default: 16)
    timeout       => timeout in seconds (default: 300)

This function loads the null_blk module with nr_devices=0, finds the first
available null_blk device index, creates and configures the zoned device
through configfs, enables it, and sets the mq-deadline scheduler.

Returns: the device path (e.g., '/dev/nullb0')

=cut

sub create_zoned_nullblk {
    my (%opts) = @_;
    my $bs = $opts{blocksize} // 4096;
    my $zs = $opts{zone_size} // 256;
    my $nr_conv = $opts{zone_nr_conv} // 4;
    my $nr_seq = $opts{zone_nr_seq} // 16;
    my $timeout = $opts{timeout} // 300;

    assert_script_run('modprobe null_blk nr_devices=0', $timeout);

    my $nid = script_output('for i in {0..256}; do test -b /dev/nullb$i || { echo $i; break; }; done');
    die "Unable to find a free null_blk device index" if (!defined $nid || $nid !~ /^\d+$/);

    my $dev = "/sys/kernel/config/nullb/nullb$nid";
    assert_script_run("mkdir $dev", $timeout);

    my $cap = $zs * ($nr_conv + $nr_seq);

    assert_script_run("echo $bs > $dev/blocksize", $timeout);
    assert_script_run("echo 0 > $dev/completion_nsec", $timeout);
    assert_script_run("echo 0 > $dev/irqmode", $timeout);
    assert_script_run("echo 2 > $dev/queue_mode", $timeout);
    assert_script_run("echo 1024 > $dev/hw_queue_depth", $timeout);
    assert_script_run("echo 1 > $dev/memory_backed", $timeout);
    assert_script_run("echo 1 > $dev/zoned", $timeout);

    assert_script_run("echo $cap > $dev/size", $timeout);
    assert_script_run("echo $zs > $dev/zone_size", $timeout);
    assert_script_run("echo $nr_conv > $dev/zone_nr_conv", $timeout);

    assert_script_run("echo 1 > $dev/power", $timeout);

    assert_script_run("udevadm settle || sleep 2", $timeout);
    assert_script_run("test -b /dev/nullb$nid", $timeout);

    script_run("echo mq-deadline > /sys/block/nullb$nid/queue/scheduler");

    return "/dev/nullb$nid";
}

=head2 start_block_trace

 start_block_trace($dev, $log);
 start_block_trace($dev, $log, $mask);

Start a background C<blktrace> on a block device, piped into C<blkparse>, to
record the requests reaching the device while a test runs. Use
C<stop_block_trace> to end it and C<count_block_writes> to evaluate the result.

Arguments:
  $dev  - Block device to trace (e.g. '/dev/loop0')
  $log  - Path of the blkparse output file to write
  $mask - Optional blktrace action mask (default: write)

blktrace needs debugfs, so it gets mounted if it is not available yet.

Returns: the blktrace pid

=cut

sub start_block_trace {
    my ($dev, $log, $mask) = @_;
    $mask //= 'write';

    script_run('mountpoint -q /sys/kernel/debug || mount -t debugfs none /sys/kernel/debug');
    return background_script_run("blktrace -d $dev -a $mask -o - | blkparse -i - > $log 2>&1");
}

=head2 stop_block_trace

 stop_block_trace();

Stop the trace started by C<start_block_trace>. blktrace is interrupted rather
than killed, so that it closes the pipe and blkparse flushes its output.

=cut

sub stop_block_trace {
    script_run('pkill -INT blktrace; sleep 3');
}

=head2 count_block_writes

 count_block_writes($log);

Count the write requests in a blkparse output file and return the number. The
RWBS field of an event holds C<W> followed by optional modifiers like C<S> for
sync or C<M> for metadata, the summary lines at the end of the file spell the
direction out and are not counted.

=cut

sub count_block_writes {
    my ($log) = @_;

    my ($count) = script_output("grep -cE ' W[A-Z]* ' $log || true", proceed_on_failure => 1) =~ /(\d+)/;
    return $count;
}

1;
