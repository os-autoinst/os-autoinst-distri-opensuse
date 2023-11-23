# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: verify lock package works after migation test.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package verify_lock_package;
use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';

    # Packages to be locked is comma-separated
    my @pkgs = split(/,/, get_var('LOCK_PACKAGE'));
    my $old_version_str = get_var('LOCK_PACKAGE_VERSIONS');
    my $version_str = '';
    for my $pkg (@pkgs) {
        # Save each package's name, version and release info to variable
        my $fullname = script_output "rpm -q $pkg";
        $version_str = $version_str ? join(',', $version_str, $fullname) : $fullname;
    }
    die "The packages hadn't been locked as expected, origin: $old_version_str new: $version_str" if ($version_str ne $old_version_str);
}

sub test_flags {
    return {fatal => 1};
}

1;
