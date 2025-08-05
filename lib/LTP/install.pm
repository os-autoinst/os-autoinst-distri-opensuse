# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: LTP helper functions
# Maintainer: Martin Doucha <mdoucha@suse.cz>

package LTP::install;

use base Exporter;
use strict;
use warnings;
use testapi;
use Utils::Backends;
use autotest;
use version_utils qw(is_sle is_rt);
use File::Basename 'basename';
use Utils::Architectures;
use utils;

our @EXPORT = qw(
  get_required_build_dependencies
  get_maybe_build_dependencies
  get_submodules_to_rebuild
);

sub get_required_build_dependencies {
    my @deps = qw(
      autoconf
      automake
      bison
      expect
      flex
      gcc
      git-core
      libaio-devel
      libopenssl-devel
      make
    );

    if (is_rt) {
        push @deps, 'kernel-rt-devel';
    }
    elsif (!get_var('KGRAFT')) {
        push @deps, 'kernel-default-devel';
    }

    return @deps;
}

sub get_maybe_build_dependencies {
    my @maybe_deps = qw(
      gcc-32bit
      kernel-default-devel-32bit
      keyutils-devel
      keyutils-devel-32bit
      libacl-devel
      libacl-devel-32bit
      libaio-devel-32bit
      libcap-devel
      libcap-devel-32bit
      libmnl-devel
      libnuma-devel
      libnuma-devel-32bit
      libselinux-devel
      libselinux-devel-32bit
      libtirpc-devel
      libtirpc-devel-32bit
    );

    # libopenssl-devel-32bit is blocked by dependency mess on SLE-12 and we
    # don't use it anyway...
    push @maybe_deps, 'libopenssl-devel-32bit' if !is_sle('<15');

    return @maybe_deps;
}

sub get_submodules_to_rebuild {
    my @submodules = qw(
      commands/insmod
      kernel/device-drivers
      kernel/firmware
      kernel/syscalls/delete_module
      kernel/syscalls/finit_module
      kernel/syscalls/init_module
    );

    return @submodules;
}

1;
