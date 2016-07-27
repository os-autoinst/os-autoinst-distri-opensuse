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

# fate#320678 GCC 4.8 on SDK for AArch64
sub run() {
    select_console 'user-console';
    my $repo     = 'SDK';
    my @packages = qw/gcc48 gcc48-c++ gcc48-fortran gcc48-info gcc48-locale gcc48-objc gcc48-obj-c++ libstdc++48-devel/;
    for my $package (@packages) {
        diag "checking package $package";
        assert_script_run('zypper search --details ' . $package);
        assert_script_run('zypper search --details ' . $package . ' | grep \'\<' . $package . '\>\s\+.*' . $repo . '\'');
    }
}

1;
# vim: set sw=4 et:
