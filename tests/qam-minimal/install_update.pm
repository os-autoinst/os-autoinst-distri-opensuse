# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


# Summary: QAM Minimal test in openQA
#    it prepares minimal instalation, boot it, install tested incident , try
#    reboot and update system with all released updates.
#
#    with QAM_MINIMAL=full it also installs gnome-basic, base, apparmor and
#    x11 patterns and reboot system to graphical login + start console and
#    x11 tests
# Maintainer: Ondřej Súkup <osukup@suse.cz>

use base "opensusebasetest";

use strict;
use warnings;

use utils;
use power_action_utils 'prepare_system_shutdown';
use version_utils 'is_sle';
use qam;
use testapi;

sub run {
    my ($self) = @_;
    select_console 'root-console';

    capture_state('before');

    # Set and check patch variables
    my $incident_id = get_var('INCIDENT_ID');
    my $patch       = get_var('INCIDENT_PATCH');
    check_patch_variables($patch, $incident_id);

    my $repo = get_required_var('INCIDENT_REPO');
    set_var('MAINT_TEST_REPO', $repo);
    add_test_repositories;

    # Get patch list related to incident
    my $patches = '';
    $patches = get_patches($incident_id, $repo) if $incident_id;

    # test if is patch needed and record_info
    # record softfail on QAM_MINIMAL=small tests, or record info on others
    # if isn't patch neded, zypper call with install makes no sense
    if ((is_patch_needed($patch) && $patch) || ($incident_id && !($patches))) {
        if (check_var('QAM_MINIMAL', 'small')) {
            record_soft_failure("Patch isn't needed on minimal installation poo#17412");
        }
        else {
            record_info('Not needed', q{Patch doesn't fix any package in minimal pattern});
        }
    }
    else {
        # Use single patch or patch list
        $patch = $patch ? $patch : $patches;
        zypper_call("in -l -t patch ${patch}", exitcode => [0, 102, 103], log => 'zypper.log');

        save_screenshot;

        capture_state('between', 1);

        # check if latest kernel has valid secure boot signature
        if (check_var('MACHINE', 'uefi') && is_sle('12-sp1+')) {
            assert_script_run 'kexec -l -s /boot/vmlinuz --initrd=/boot/initrd --reuse-cmdline';
            script_run 'umount -a';
            script_run 'mount -o remount,ro /';
            type_string "kexec -e\n";
            assert_screen 'linux-login';
            type_string "root\n";
            wait_still_screen 3;
            type_password;
            wait_still_screen 3;
            send_key 'ret';
            assert_script_run 'uname -a';
            assert_script_run 'mokutil --sb-state';
            assert_script_run 'mokutil --list-enrolled';
        }

        prepare_system_shutdown;
        type_string "reboot\n";
        $self->wait_boot;
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
