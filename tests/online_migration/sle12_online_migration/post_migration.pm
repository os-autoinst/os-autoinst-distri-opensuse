# SLE12 online migration tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: sle12 online migration testsuite
# Maintainer: mitiao <mitiao@gmail.com>

use base "installbasetest";
use strict;
use testapi;
use utils;

sub run() {
    select_console 'root-console';

    # print repos to screen and serial console after online migration
    wait_still_screen;
    script_run("zypper lr -u | tee /dev/$serialdev");
    save_screenshot;

    # nvidia repo is always updated by scc during migration
    # we have to disable it after migration if find workaround
    if (check_var('SOFTFAIL', 'bsc#1013208')) {
        assert_script_run "zypper mr -d \$(zypper lr | grep -i nvidia | awk \'{print \$1}\')";
        record_soft_failure 'workaround for bsc#1013208, disable nvidia repo after migration';
    }

    select_console 'x11';
    ensure_unlocked_desktop;
    mouse_hide(1);
    assert_screen 'generic-desktop';
}

sub test_flags {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
