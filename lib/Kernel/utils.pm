# SUSE's openQA tests
#
# Copyright 2018-2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Generic kernel-related helpers shared across kernel test modules.
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kernel::utils;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use utils qw(systemctl zypper_search);
use package_utils;
use version_utils qw(is_sle is_sle_micro is_transactional);
use transactional;

our @EXPORT_OK = qw(
  is_debugfs_mounted
  enable_debugfs
  get_initial_kernel_flavor
  get_kernel_flavor
  get_kernel_source_flavor
  get_kernel_devel_flavor
  get_kernel_devel_libs
  remove_kernel_packages
  check_kernel_package
  is_kernel_validation_flavor
);

=head1 SYNOPSIS

Generic kernel-related helpers shared across kernel test modules: debugfs
handling and kernel package/flavor management.

=cut

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

=head2 get_initial_kernel_flavor

 get_initial_kernel_flavor();

Kernel flavor preinstalled on the boot disk.

=cut

sub get_initial_kernel_flavor {
    my $kernel_package = 'kernel-default';

    $kernel_package = 'kernel-default-base' if is_sle('<12');
    $kernel_package = 'kernel-rt' if check_var('SLE_PRODUCT', 'slert');
    return $kernel_package;
}

=head2 get_kernel_flavor

 get_kernel_flavor();

Kernel flavor that needs to be installed before running tests.

=cut

sub get_kernel_flavor {
    my $kernel_package = get_initial_kernel_flavor();

    $kernel_package = 'kernel-default-base' if get_var('KERNEL_BASE');
    $kernel_package = 'kernel-azure' if get_var('AZURE');
    $kernel_package = 'kernel-coco' if get_var('COCO');
    $kernel_package = 'kernel-64kb' if get_var('KERNEL_64KB');
    return get_var('KERNEL_FLAVOR', $kernel_package);
}

=head2 get_kernel_source_flavor

 get_kernel_source_flavor();

=cut

sub get_kernel_source_flavor {
    my $src_pack = 'kernel-source';

    if (check_var('SLE_PRODUCT', 'slert')) {
        $src_pack = 'kernel-source-rt'
          unless is_sle('16+') || is_sle_micro('6.2+');
    }
    elsif (get_var('COCO')) {
        $src_pack = 'kernel-source-coco';
    }

    return $src_pack;
}

=head2 get_kernel_devel_flavor

 get_kernel_devel_flavor();

=cut

sub get_kernel_devel_flavor {
    my $devel_pack = 'kernel-devel';

    if (check_var('SLE_PRODUCT', 'slert')) {
        $devel_pack = 'kernel-devel-rt'
          unless is_sle('16+') || is_sle_micro('6.2+');
    }
    elsif (get_var('COCO')) {
        $devel_pack = 'kernel-devel-coco';
    }

    return $devel_pack;
}

=head2 get_kernel_devel_libs

 get_kernel_devel_libs();

=cut

sub get_kernel_devel_libs {
    my $devel_pack = 'kernel-default-devel';

    if (check_var('SLE_PRODUCT', 'slert')) {
        $devel_pack = 'kernel-rt-devel';
    }

    return $devel_pack;
}

=head2 remove_kernel_packages

 remove_kernel_packages();

=cut

sub remove_kernel_packages {
    my @packages = map { $_->{name} } @{zypper_search('-i kernel')};
    @packages = grep { m/^kernel-(?!firmware)/ } @packages;
    my @rmpacks = @packages;

    push @rmpacks, 'multipath-tools'
      if !get_var('KGRAFT') and scalar @{zypper_search('-i --match-exact multipath-tools')};

    uninstall_package(join(' ', @rmpacks));
    return @packages;
}

=head2 check_kernel_package

 check_kernel_package($kernel_name);

Check that only the given kernel flavor is installed.

=cut

sub check_kernel_package {
    my $kernel_name = shift;

    enter_trup_shell(global_options => '-c') if is_transactional;
    script_run("bash -O nullglob -c 'ls -1 /boot/vmlinu[xz]* /boot/[Ii]mage* /usr/lib/modules/*/[Ii]mage*'");
    # Only check versioned kernels in livepatch tests. Some old kernel
    # packages install /boot/vmlinux symlink but don't set package ownership.
    my $glob = get_var('KGRAFT', 0) ? '-*' : '*';
    my $cmd = "bash -O nullglob -c 'rpm -qf --qf \"%{NAME}\\n\" /boot/vmlinu[xz]$glob /boot/[Ii]mage$glob /usr/lib/modules/*/[Ii]mage$glob'";
    my $packs = script_output($cmd);
    exit_trup_shell if is_transactional;

    for my $packname (split /\s+/, $packs) {
        die "Unexpected kernel package $packname is installed, test may boot the wrong kernel"
          if $packname ne $kernel_name;
    }
}

=head2 is_kernel_validation_flavor

 is_kernel_validation_flavor();

Check if flavor is validation.

=cut

sub is_kernel_validation_flavor {
    return get_var('FLAVOR', '') =~ /(Online-Immutable|Full-QR|Online-QR|Online|Online-Kernel-(Nvidia|RT|Base|Azure|Baremetal|(RT|64kb)-Baremetal))$/;
}

1;
