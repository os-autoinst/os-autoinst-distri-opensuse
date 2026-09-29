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
  get_verified_shallow_tar
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

=head2 get_verified_shallow_tar

 get_verified_shallow_tar(tree => 'stable', branch => 'linux-6.12.y', commit => '...');

Downloads the kernel.org shallow-clone tarball for the given C<tree> and
C<branch>, verifies it via the signed checksums, and checks out C<commit>
into F<./linux>. C<commit> should always be supplied in CI; omitting it
checks out the current tip (the bundle is published nightly).

See L<https://people.kernel.org/monsieuricon/using-shallow-git-tarballs-for-ci>.

=cut

sub get_verified_shallow_tar {
    my (%args) = @_;
    my $tree = $args{tree} // 'torvalds';
    my $branch = $args{branch} // 'master';
    my $commit = $args{commit} // '';

    my $script = 'get-verified-shallow-tar';
    assert_script_run('curl -fO ' . autoinst_url("/data/kernel/$script"));
    assert_script_run("chmod +x $script");
    assert_script_run('export GNUPGHOME=""');
    my $cmd = "./$script $tree $branch";
    $cmd .= " $commit" if $commit;
    assert_script_run($cmd, 1800);
}

1;
