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
use version_utils 'is_sle';
use warnings;

our @EXPORT = qw(
  remove_kernel_packages
  get_kernel_flavor
);

sub get_kernel_flavor {
    return get_var('KERNEL_FLAVOR', 'kernel-default');
}

sub remove_kernel_packages {
    my @packages;

    if (check_var('SLE_PRODUCT', 'slert')) {
        @packages = qw(kernel-rt kernel-rt-devel kernel-source-rt);
    }
    elsif (get_kernel_flavor eq 'kernel-64kb') {
        @packages = qw(kernel-64kb*);
    }
    else {
        @packages = qw(kernel-default kernel-default-devel kernel-macros kernel-source);
    }

    # SLE12 and SLE12SP1 has xen kernel
    if (is_sle('<=12-SP1')) {
        push @packages, qw(kernel-xen kernel-xen-devel);
    }

    push @packages, "multipath-tools"
      if is_sle('>=15-SP3') and !get_var('KGRAFT');
    zypper_call('-n rm ' . join(' ', @packages), exitcode => [0, 104]);

    return @packages;
}

1;
