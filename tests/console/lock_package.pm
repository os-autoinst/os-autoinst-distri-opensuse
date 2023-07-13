# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: lock package test mainly used for migration testsuite - poo#17206
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

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
