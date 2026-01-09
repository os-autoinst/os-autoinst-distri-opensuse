# X11 regression tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Common setup for x11 tests
# - Switch to X11 (make sure that is running in graphics mode)
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "x11test";
use testapi;
use utils 'ensure_serialdev_permissions';
use version_utils qw(is_leap);

sub run {
    select_console 'root-console';
    ensure_serialdev_permissions;
    #Switch to x11 console, if not selected, before trying to start xterm
    select_console('x11');
    # xterm is not installed by default anymore in leap 16
    # there is pending work to switch tests to not depend on
    # xterm See https://progress.opensuse.org/issues/169162
    ensure_installed('xterm') if is_leap('=16.0');
}

# add milestone flag to save setup in lastgood vm snapshot
sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
