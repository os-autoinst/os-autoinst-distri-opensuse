# X11 regression tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Common setup for x11 tests
# - Switch to X11 (make sure that is running in graphics mode)
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils 'ensure_serialdev_permissions';

sub run {
    select_console 'root-console';
    ensure_serialdev_permissions;
    #Switch to x11 console, if not selected, before trying to start xterm
    select_console('x11');
}

# add milestone flag to save setup in lastgood vm snapshot
sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
