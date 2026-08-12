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
  get_kernel_config
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

=head2 get_kernel_config

 get_kernel_config();

Locates the running kernel's config file (C</boot/config-$(uname -r)>,
falling back to C</usr/lib/modules/$(uname -r)/config> and then
C</proc/config.gz>) and records its full contents via C<record_info()>,
prefixed with a comment naming the source file (as done in
C<LTP::utils::log_versions>).

=cut

sub get_kernel_config {
    my $config = script_output(
        'ls -U "/boot/config-$(uname -r)" "/usr/lib/modules/$(uname -r)/config" /proc/config.gz 2>/dev/null | head -n 1',
        proceed_on_failure => 1
    );

    unless ($config) {
        record_info('kernel config', 'No kernel config file found');
        return;
    }

    upload_logs($config, failok => 1);

    my $cmd = "echo '# $config'; echo; " . ($config =~ /\.gz$/ ? "zcat $config" : "cat $config");
    record_info('kernel config', script_output($cmd));
}

1;
