# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP


# Summary: QAM Minimal test in openQA
#    it prepares minimal installation, boot it, install tested incident , try
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
use qam;
use version_utils 'is_sle';
use testapi;

sub install_packages {
    my $patch_info = shift;
    my $pattern = qr/\s+(.+)(?!\.src)\..*\s<\s.*/;

    # loop over packages in patchinfo and try installation
    foreach my $line (split(/\n/, $patch_info)) {
        if (my ($package) = $line =~ $pattern and $line !~ "xen-tools-domU" and $line !~ "-devel") {
            zypper_call("in $package");
            save_screenshot;
        }
    }
}

sub run {
    my ($self) = @_;
    my $incident_id = get_var('INCIDENT_ID');
    my $patch = get_var('INCIDENT_PATCH');
    my $repo = get_var('INCIDENT_REPO');
    check_patch_variables($patch, $incident_id);

    select_console 'root-console';
    my $patches = '';
    $patches = get_patches($incident_id, $repo) if $incident_id;

    quit_packagekit;
    zypper_call("ref");
    zypper_call("pt");
    save_screenshot;

    zypper_call("in -t pattern base x11 " . (is_sle('>=15') ? 'gnome_basic' : 'gnome-basic') . " apparmor", exitcode => [0, 102], timeout => 2000);

    systemctl 'set-default graphical.target';
    script_run('sed -i -r "s/^DISPLAYMANAGER=\"\"/DISPLAYMANAGER=\"gdm\"/" /etc/sysconfig/displaymanager');
    script_run('sed -i -r "s/^DISPLAYMANAGER_AUTOLOGIN/#DISPLAYMANAGER_AUTOLOGIN/" /etc/sysconfig/displaymanager');
    script_run('sed -i -r "s/^DEFAULT_WM=\"icewm\"/DEFAULT_VM=\"\"/" /etc/sysconfig/windowmanager');
    # now we have gnome installed - restore DESKTOP variable
    set_var('DESKTOP', get_var('FULL_DESKTOP'));

    $patch = $patch ? $patch : $patches;
    my $patch_status = is_patch_needed($patch, 1);
    install_packages($patch_status) if $patch_status;

    prepare_system_shutdown;
    enter_cmd "reboot";
    $self->wait_boot(bootloader_time => 200);
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    select_console('root-console');

    assert_script_run "save_y2logs /tmp/y2logs-fail.tar.bz2";
    upload_logs "/tmp/y2logs-fail.tar.bz2";
}

1;
