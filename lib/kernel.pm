# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
use 5.018;
use testapi;
use utils;
use version_utils 'is_sle';
use warnings;

our @EXPORT_OK = qw(
  remove_kernel_packages
);

sub remove_kernel_packages {
    my @packages;

    if (check_var('SLE_PRODUCT', 'slert')) {
        @packages = qw(kernel-rt kernel-rt-devel kernel-source-rt);
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

