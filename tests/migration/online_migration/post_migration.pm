# SLE12 online migration tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: SUSEConnect zypper
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
use migration 'disable_kernel_multiversion';

sub run {
    select_console 'root-console';

    # print repos to screen and serial console after online migration
    assert_script_run "zypper lr --uri | tee /dev/$serialdev";

    # Save output info to logfile
    my $out;
    my $timeout = bmwqemu::scale_timeout(30);
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

    # enable multiversion for kernel-default based on bsc#1097111, for migration continuous cases only
    if (get_var('FLAVOR', '') =~ /Continuous-Migration/) {
        record_soft_failure 'bsc#1097111 - File conflict of SLE12 SP3 and SLE15 kernel';
        disable_kernel_multiversion;
    }

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
