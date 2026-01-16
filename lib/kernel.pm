# SUSE's openQA tests
#
# Copyright 2018-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Kernel helper functions
# Maintainer: Kernel QE <kernel-qa@suse.de>

package kernel;

use base Exporter;
use testapi;
use strict;
use utils;
use package_utils;
use version_utils qw(is_sle is_sle_micro is_transactional);
use transactional;
use warnings;

our @EXPORT = qw(
  remove_kernel_packages
  get_initial_kernel_flavor
  get_kernel_flavor
  get_kernel_source_flavor
  get_kernel_devel_flavor
  check_kernel_package
);

# Kernel flavor preinstalled on the boot disk
sub get_initial_kernel_flavor {
    my $kernel_package = 'kernel-default';

    $kernel_package = 'kernel-default-base' if is_sle('<12');
    $kernel_package = 'kernel-rt' if check_var('SLE_PRODUCT', 'slert');
    return $kernel_package;
}

# Kernel flavor that needs to be installed before running tests
sub get_kernel_flavor {
    my $kernel_package = get_initial_kernel_flavor();

    $kernel_package = 'kernel-default-base' if get_var('KERNEL_BASE');
    $kernel_package = 'kernel-azure' if get_var('AZURE');
    $kernel_package = 'kernel-coco' if get_var('COCO');
    $kernel_package = 'kernel-64kb' if get_var('KERNEL_64KB');
    return get_var('KERNEL_FLAVOR', $kernel_package);
}

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

sub remove_kernel_packages {
    my @packages = map { $_->{name} } @{zypper_search('-i kernel')};
    @packages = grep { m/^kernel-(?!firmware)/ } @packages;
    my @rmpacks = @packages;
    push @rmpacks, "multipath-tools"
      if is_sle('>=15-SP3') and !get_var('KGRAFT');

    uninstall_package(join(' ', @rmpacks));
    return @packages;
}

# Check that only the given kernel flavor is installed
sub check_kernel_package {
    my $kernel_name = shift;

    enter_trup_shell(global_options => '-c') if is_transactional;
    script_run("bash -O nullglob -c 'ls -1 /boot/vmlinu[xz]* /boot/[Ii]mage*'");
    # Only check versioned kernels in livepatch tests. Some old kernel
    # packages install /boot/vmlinux symlink but don't set package ownership.
    my $glob = get_var('KGRAFT', 0) ? '-*' : '*';
    my $cmd = "bash -O nullglob -c 'rpm -qf --qf \"%{NAME}\\n\" /boot/vmlinu[xz]$glob /boot/[Ii]mage$glob'";
    my $packs = script_output($cmd);
    exit_trup_shell if is_transactional;

    for my $packname (split /\s+/, $packs) {
        die "Unexpected kernel package $packname is installed, test may boot the wrong kernel"
          if $packname ne $kernel_name;
    }
}

1;
