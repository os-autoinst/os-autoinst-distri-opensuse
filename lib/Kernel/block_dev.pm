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

1;
