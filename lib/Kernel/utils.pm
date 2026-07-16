# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Generic kernel-related helpers shared across kernel test modules.
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kernel::utils;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use utils 'systemctl';

our @EXPORT_OK = qw(
  is_debugfs_mounted
  enable_debugfs
);

=head2 is_debugfs_mounted

 is_debugfs_mounted();

Checks whether debugfs is mounted at /sys/kernel/debug, same check as
blktests' C<_have_debugfs()>. Returns true/false.

=cut

sub is_debugfs_mounted {
    return script_run('findmnt -t debugfs /sys/kernel/debug') == 0;
}

=head2 enable_debugfs

 enable_debugfs();

Mounts debugfs at /sys/kernel/debug (e.g. on SLE 16.1+, where it is
disabled by default per PED-8812).

=cut

sub enable_debugfs {
    record_info('debugfs', 'debugfs not mounted, enabling sys-kernel-debug.mount');
    systemctl('enable --now sys-kernel-debug.mount');
}

1;
