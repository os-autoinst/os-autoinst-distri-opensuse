# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
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
use version_utils qw(sle_version_at_least is_jeos);

my %packages = (
    # On JeOS Salt is present in the default image
    salt => {
        repo      => 'Basesystem',
        installed => is_jeos() ? 1 : 0
    });

sub run {
    select_console 'root-console';
    # for now only test for SLE>=15
    return unless sle_version_at_least('15');
    for my $package (keys %packages) {
        my $args = $packages{$package}->{installed} ? '--installed-only' : '--not-installed-only';
        assert_script_run("zypper se -n $args --match-exact --details $package | grep " . $packages{$package}->{repo});
    }
}

1;
