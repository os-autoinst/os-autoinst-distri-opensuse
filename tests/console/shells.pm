# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test all officially SLE supported shells
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use version_utils 'is_leap';

sub run() {
    select_console 'root-console';
    my @packages = qw(tcsh zsh);
    # ksh does not build for Leap 15.x on aarch64, so, skip it
    push @packages, qw(ksh) unless (is_leap('15.0+') and check_var('ARCH', 'aarch64'));
    zypper_call("in @packages");
    select_console 'user-console';
    assert_script_run 'ksh -c "print hello" | grep hello' unless (is_leap('15.0+') and check_var('ARCH', 'aarch64'));
    assert_script_run 'tcsh -c "printf \'hello\n\'" | grep hello';
    assert_script_run 'csh -c "printf \'hello\n\'" | grep hello';
    assert_script_run 'zsh -c "echo hello" | grep hello';
    assert_script_run 'sh -c "echo hello" | grep hello';
}

1;
