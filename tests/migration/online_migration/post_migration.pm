# SLE12 online migration tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: SUSEConnect zypper
# Summary: sle12 online migration testsuite
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "installbasetest";
use testapi;
use utils;
use version_utils qw(is_desktop_installed is_sles4sap is_sle);
use Utils::Backends qw(is_pvm);
use power_action_utils qw(power_action);
use qam qw(add_test_repositories remove_test_repositories);
use x11utils qw(ensure_unlocked_desktop);
use migration qw(modify_kernel_multiversion);

sub run {
    my ($self) = @_;
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
        modify_kernel_multiversion("enable");
    }

    $self->add_maintenance_repos() if (get_var('MAINT_TEST_REPO'));

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
    my ($self) = @_;
    set_var('PATCH_TEST_REPO', '');
    add_test_repositories();
    # avoid reboot during fully_patch_system
    zypper_call('in pacemaker') if is_sle('=15-sp1');
    if (fully_patch_system() == 102) {    # zypper suggests a reboot
        power_action('reboot', textmode => 1);
        reconnect_mgmt_console if is_pvm;
        # Do not log in if SUT is SLES4SAP
        $self->wait_boot(textmode => !is_desktop_installed, bootloader_time => 500, ready_time => 600, nologin => is_sles4sap);
    }

}

1;
