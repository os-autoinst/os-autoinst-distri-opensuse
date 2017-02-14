# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run simple checks after installation
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    if (check_var('SYSTEM_ROLE', 'worker')) {
        # poo#16574
        # Should be replaced by actually connecting to admin node when it's implemented
        assert_script_run "grep \"master: 'dashboard-url'\" /etc/salt/minion.d/master.conf";
    }
}

1;
# vim: set sw=4 et:
