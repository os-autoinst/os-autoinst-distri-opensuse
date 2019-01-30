# SLE12 online migration tests
#
# Copyright © 2016-2019 SUSE LLC
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
use version_utils 'is_desktop_installed';
use qam qw(add_test_repositories remove_test_repositories);
use x11utils 'ensure_unlocked_desktop';

sub run {
    select_console 'root-console';

    # print repos to screen and serial console after online migration
    zypper_call('lr -u');

    add_maintenance_repos() if (get_var('MAINT_TEST_REPO'));

    if (is_desktop_installed) {
        select_console 'x11', await_console => 0;
        ensure_unlocked_desktop;
        mouse_hide(1);
        assert_screen 'generic-desktop';
    }
}

sub test_flags {
    return {fatal => 1};
}

sub add_maintenance_repos {
    set_var('PATCH_TEST_REPO', '');
    add_test_repositories();
    fully_patch_system();
}

1;
