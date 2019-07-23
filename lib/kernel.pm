# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
use 5.018;
use testapi;
use utils;
use version_utils 'is_sle';
use warnings;

our @EXPORT_OK = qw(
  remove_kernel_packages
);

sub remove_kernel_packages {
    my @packages = qw(kernel-default kernel-default-devel kernel-macros kernel-source);

    # SLE12 and SLE12SP1 has xen kernel
    if (is_sle('<=12-SP1')) {
        push @packages, qw(kernel-xen kernel-xen-devel);
    }

    zypper_call('-n rm ' . join(' ', @packages), exitcode => [0, 104]);

    return @packages;
}

