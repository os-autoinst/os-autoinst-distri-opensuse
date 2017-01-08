# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: First boot and login into CASP
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    if (!check_var('ARCH', 's390x')) {
        assert_screen 'linux-login', 200;
    }
    select_console 'root-console';
}

sub test_flags() {
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
