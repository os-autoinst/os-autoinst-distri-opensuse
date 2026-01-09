# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate individual packages installed or not in the system
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'consoletest';
use testapi;

sub run {
    select_console 'root-console';

    my @packages_list = split(/,/, get_var('PACKAGES'));
    my %packages = map { $_ => {installed => 1} } @packages_list;

    for my $name (keys %packages) {
        my $result = script_run "zypper se -i -t package $name";
        die "The expected package $name is not installed." if $result != 0;
    }
}

1;
