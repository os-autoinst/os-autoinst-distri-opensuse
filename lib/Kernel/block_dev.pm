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
  record_storage_info
);

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
