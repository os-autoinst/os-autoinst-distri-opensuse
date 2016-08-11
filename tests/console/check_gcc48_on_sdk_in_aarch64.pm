# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use strict;
use testapi;

# Maintainer: okurz@suse.de
# Summary: fate#320678 GCC 4.8 on SDK for AArch64
sub run() {
    select_console 'user-console';
    my $not_repo = 'SLE';
    my $repo     = 'SDK';
    my @packages = qw/gcc48 gcc48-c++ gcc48-fortran gcc48-info gcc48-locale gcc48-objc gcc48-obj-c++ libstdc++48-devel/;
    for my $package (@packages) {
        diag "checking package $package (only binary packages)";
        script_run('zypper search -t package --details ' . $package);
        diag "checking package $package is *not* in repo \'$not_repo\'";
        assert_script_run('! zypper search -t package --details ' . $package . ' | grep \'\<' . $package . '\>\s\+.*' . $not_repo . '\'');
        if (get_var('ADDONS', '') =~ /sdk/) {
            diag "checking package $package *is* in repo \'$repo\'";
            assert_script_run('zypper search -t package --details ' . $package . ' | grep \'\<' . $package . '\>\s\+.*' . $repo . '\'');
        }
    }
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:
