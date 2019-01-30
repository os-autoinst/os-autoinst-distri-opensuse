# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: check locked package after lock package test applied
# Maintainer: Wei Jiang <wjiang@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;

sub run {
    select_console 'root-console';

    # List each active package lock and check its version and release info
    for my $pkg (@{$lock_package::locked_pkg_info}) {
        assert_script_run "zypper ll | grep $pkg->{name}";
        assert_script_run "rpm -q $pkg->{name} | grep $pkg->{fullname}";
    }
    # perl -c will give a "only used once" message
    # here and this makes the travis ci tests fail.
    1 if defined $lock_package::locked_pkg_info;
}

sub test_flags {
    return {fatal => 1};
}

1;
