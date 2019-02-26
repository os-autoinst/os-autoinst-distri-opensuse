# X11 regression tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Common setup for x11 tests
# Maintainer: mitiao <mitiao@gmail.com>

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
