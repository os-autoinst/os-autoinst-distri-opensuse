# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: lock package test mainly used for migration testsuite - poo#17206
# Maintainer: Wei Jiang <wjiang@suse.com>

package lock_package;
use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

our $locked_pkg_info = [];

sub run {
    select_console 'root-console';

    # Packages to be locked is comma-separated
    my @pkgs = split(/,/, get_var('LOCK_PACKAGE'));
    for my $pkg (@pkgs) {
        # Save each package's name, version and release info to variable
        my $fullname = script_output "rpm -q $pkg";
        push @$locked_pkg_info, {name => $pkg, fullname => $fullname};

        # Add a lock for each package
        zypper_call "al $pkg";
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
