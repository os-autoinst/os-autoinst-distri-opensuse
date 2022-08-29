# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: PackageKit
# Summary: Simple pkcon test
# - check basic commands of pkcon
# - install package with options
# Maintainer: Zaoliang Luo <zluo@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use registration;
use version_utils 'is_sle';

sub run {
    my @command = qw(refresh repo-list backend-details get-roles get-groups get-filters);
    my $pkgname = "coreutils";

    select_console 'root-console';
    # need to add required product at first
    add_suseconnect_product('sle-module-desktop-applications', undef, undef, undef, 300, 1) if is_sle(">=15");

    zypper_call('in PackageKit');
    # on sles and tw we need to unmask packagekit service because it got masked on the qcow2 image
    assert_script_run("systemctl unmask packagekit.service");
    assert_script_run("systemctl start packagekit.service");

    # let's now check some sub commands of pkcon and re-install package coreutils
    foreach (@command) {
        script_run "pkcon $_";
    }
    script_run("pkcon install $pkgname --allow-reinstall --allow-downgrade -y", 300);

    # restore previous state for packagekit service
    quit_packagekit;
}

1;

