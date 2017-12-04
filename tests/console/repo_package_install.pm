# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: check SLE repositories, packages and installation status
# Maintainer: Zaoliang Luo <zluo@suse.com>

use base "consoletest";
use strict;
use testapi;
use utils;
use version_utils 'sle_version_at_least';

my %packages = (
    salt => {
        repo      => 'Basesystem',
        installed => 0
    });

sub run {
    select_console 'root-console';
    # for now only test for SLE>=15
    return unless sle_version_at_least('15');
    for my $package (keys %packages) {
        my $args = $packages{$package}->{installed} ? '--installed-only' : '--not-installed-only';
        zypper_call('se ' . $args . ' --match-exact --details ' . $package . ' | grep ' . $packages{$package}->{repo});
    }
}

1;
# vim: set sw=4 et:
