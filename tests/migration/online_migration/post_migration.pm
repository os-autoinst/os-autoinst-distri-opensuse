# SLE12 online migration tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: sle12 online migration testsuite
# Maintainer: yutao <yuwang@suse.com>

use base "installbasetest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_desktop_installed is_sles4sap is_sle);
use qam qw(add_test_repositories remove_test_repositories);
use x11utils 'ensure_unlocked_desktop';

sub run {
    select_console 'root-console';

    # print repos to screen and serial console after online migration
    zypper_call('lr -u');

    # Save output info to logfile
    my $out;
    my $timeout  = bmwqemu::scale_timeout(30);
    my $waittime = bmwqemu::scale_timeout(5);
    while (1) {
        $out = script_output("SUSEConnect --status-text", proceed_on_failure => 1);
        last if (($timeout < 0) || ($out !~ /System management is locked by the application with pid/));
        sleep $waittime;
        $timeout -= $waittime;
        diag "SUSEConnect --status-text locked: $out";
    }
    diag "SUSEConnect --status-text: $out";
    assert_script_run "SUSEConnect --status-text | grep -v 'Not Registered'" unless get_var('MEDIA_UPGRADE');

    add_maintenance_repos() if (get_var('MAINT_TEST_REPO'));

    # we need to ensure that desktop is unlocked on SLE15+ but not on any SLES4SAP
    if (is_desktop_installed && !is_sles4sap && is_sle('15+')) {
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
